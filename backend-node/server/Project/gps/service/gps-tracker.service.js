'use strict';

const mongoose = require('mongoose');
const TrackerDevice = require('../models/tracker-device.model');
const GuardLocation = require('../models/guard-location.model');
const GuardAlert = require('../models/guard-alert.model');

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;
const STALE_AFTER_MINUTES = 10;

function toNumber(value, fallback) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function cleanText(value) {
  const normalized = String(value || '').trim();
  return normalized || null;
}

function cleanCoordinates(value) {
  if (!value || typeof value !== 'object') return null;
  const latitude = Number(value.latitude);
  const longitude = Number(value.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude < -90 || latitude > 90) return null;
  if (longitude < -180 || longitude > 180) return null;
  return { latitude, longitude };
}

function buildLocationPayload(body) {
  const coordinates = cleanCoordinates(body && body.coordinates);
  if (!coordinates) {
    const error = new Error('Invalid coordinates');
    error.status = 400;
    throw error;
  }

  return {
    guardId: cleanText(body && body.guardId) || null,
    deviceId: cleanText(body && body.deviceId) || null,
    coordinates,
    accuracy: toNumber(body && body.accuracy, null),
    batteryLevel: toNumber(body && body.batteryLevel, null),
    speed: toNumber(body && body.speed, null),
    heading: toNumber(body && body.heading, null),
    capturedAt: body && body.capturedAt ? new Date(body.capturedAt) : new Date(),
    source: cleanText(body && body.source) || 'device',
    status: cleanText(body && body.status) || 'active'
  };
}

function normalizeStatus(value) {
  return String(value || '').trim().toLowerCase();
}

function isDatabaseReady() {
  return Boolean(mongoose.connection && mongoose.connection.readyState === 1);
}

const memoryStore = {
  devices: [],
  locations: [],
  alerts: []
};

function toPlainObject(value) {
  if (!value) return value;
  if (typeof value.toObject === 'function') return value.toObject();
  return value;
}

async function findDevice(deviceId) {
  if (!deviceId) return null;
  if (!isDatabaseReady()) {
    return memoryStore.devices.find(function (item) {
      return item && item.deviceId === deviceId;
    }) || null;
  }
  return TrackerDevice.findOne({ deviceId }).lean();
}

async function upsertDevice(deviceId, payload) {
  if (!deviceId) return null;
  if (!isDatabaseReady()) {
    const existingIndex = memoryStore.devices.findIndex(function (item) {
      return item && item.deviceId === deviceId;
    });
    const nextDoc = Object.assign({}, payload, { deviceId });
    if (existingIndex >= 0) {
      memoryStore.devices[existingIndex] = nextDoc;
    } else {
      memoryStore.devices.push(nextDoc);
    }
    return nextDoc;
  }

  const updated = await TrackerDevice.updateOne(
    { deviceId },
    { $set: payload },
    { upsert: true }
  ).catch(function () {
    return null;
  });

  return updated;
}

async function createLocationRecord(payload) {
  if (!isDatabaseReady()) {
    const record = Object.assign({
      _id: new mongoose.Types.ObjectId().toString(),
      createdAt: new Date(),
      updatedAt: new Date()
    }, payload);
    memoryStore.locations.push(record);
    return record;
  }

  return GuardLocation.create(payload);
}

async function listLocationRecords(filter, sortField, page, limit) {
  if (!isDatabaseReady()) {
    const rows = memoryStore.locations
      .filter(function (item) {
        return Object.keys(filter || {}).every(function (key) {
          if (key === 'capturedAt') {
            const value = filter[key];
            return item.capturedAt && item.capturedAt >= value.$gte;
          }
          return item[key] === filter[key];
        });
      })
      .sort(function (left, right) {
        return new Date(right[sortField] || right.capturedAt || 0) - new Date(left[sortField] || left.capturedAt || 0);
      })
      .slice((page - 1) * limit, page * limit);
    return { rows, total: memoryStore.locations.filter(function (item) {
      return Object.keys(filter || {}).every(function (key) {
        if (key === 'capturedAt') {
          const value = filter[key];
          return item.capturedAt && item.capturedAt >= value.$gte;
        }
        return item[key] === filter[key];
      });
    }).length };
  }

  const [rows, total] = await Promise.all([
    GuardLocation.find(filter).sort({ [sortField]: -1 }).skip((page - 1) * limit).limit(limit).lean(),
    GuardLocation.countDocuments(filter)
  ]);

  return { rows, total };
}

async function listAlertRecords(filter, page, limit) {
  if (!isDatabaseReady()) {
    const rows = memoryStore.alerts
      .filter(function (item) {
        return Object.keys(filter || {}).every(function (key) {
          return item[key] === filter[key];
        });
      })
      .sort(function (left, right) {
        return new Date(right.createdAt || 0) - new Date(left.createdAt || 0);
      })
      .slice((page - 1) * limit, page * limit);
    return { rows, total: memoryStore.alerts.filter(function (item) {
      return Object.keys(filter || {}).every(function (key) {
        return item[key] === filter[key];
      });
    }).length };
  }

  const [rows, total] = await Promise.all([
    GuardAlert.find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit).lean(),
    GuardAlert.countDocuments(filter)
  ]);
  return { rows, total };
}

exports.createLocation = async function createLocation(body) {
  const payload = buildLocationPayload(body || {});

  if (!payload.guardId && !payload.deviceId) {
    const error = new Error('guardId or deviceId is required');
    error.status = 400;
    throw error;
  }

  const device = payload.deviceId ? await findDevice(payload.deviceId) : null;

  if (!device && payload.deviceId) {
    await upsertDevice(payload.deviceId, {
      deviceId: payload.deviceId,
      name: payload.deviceId,
      status: 'online',
      lastSeenAt: new Date()
    });
  }

  const created = await createLocationRecord({
    ...payload,
    deviceName: device ? device.name : payload.deviceId,
    lastSeenAt: new Date()
  });

  await upsertDevice(payload.deviceId || device?.deviceId, {
    deviceId: payload.deviceId || device?.deviceId,
    name: device ? device.name : payload.deviceId,
    status: 'online',
    lastSeenAt: created.capturedAt || created.lastSeenAt || new Date(),
    lastCoordinates: created.coordinates
  });

  return toPlainObject(created);
};

exports.listLiveGuards = async function listLiveGuards(query) {
  const page = Math.max(toNumber(query && query.page, 1), 1);
  const limit = Math.min(Math.max(toNumber(query && query.limit, DEFAULT_LIMIT), 1), MAX_LIMIT);
  const skip = (page - 1) * limit;
  const cutoff = new Date(Date.now() - STALE_AFTER_MINUTES * 60 * 1000);

  const { rows, total } = await listLocationRecords({ capturedAt: { $gte: cutoff } }, 'capturedAt', page, limit);
  return { rows, total, page, limit, hasMore: skip + rows.length < total };
};

exports.listHistory = async function listHistory(guardId, query) {
  const page = Math.max(toNumber(query && query.page, 1), 1);
  const limit = Math.min(Math.max(toNumber(query && query.limit, DEFAULT_LIMIT), 1), MAX_LIMIT);
  const skip = (page - 1) * limit;

  const filter = guardId ? { guardId } : {};
  const { rows, total } = await listLocationRecords(filter, 'capturedAt', page, limit);
  return { rows, total, page, limit, hasMore: skip + rows.length < total };
};

exports.listAlerts = async function listAlerts(query) {
  const page = Math.max(toNumber(query && query.page, 1), 1);
  const limit = Math.min(Math.max(toNumber(query && query.limit, DEFAULT_LIMIT), 1), MAX_LIMIT);
  const skip = (page - 1) * limit;
  const filter = {};
  const status = normalizeStatus(query && query.status);
  if (status) filter.status = status;

  const { rows, total } = await listAlertRecords(filter, page, limit);
  return { rows, total, page, limit, hasMore: skip + rows.length < total };
};

exports.createAlert = async function createAlert(body) {
  const payload = {
    guardId: cleanText(body && body.guardId) || null,
    title: cleanText(body && body.title) || 'Alert',
    description: cleanText(body && body.description) || null,
    severity: cleanText(body && body.severity) || 'medium',
    status: normalizeStatus(body && body.status) || 'open'
  };

  if (!payload.guardId) {
    const error = new Error('guardId is required');
    error.status = 400;
    throw error;
  }

  if (!isDatabaseReady()) {
    const record = Object.assign({
      _id: new mongoose.Types.ObjectId().toString(),
      createdAt: new Date(),
      updatedAt: new Date()
    }, payload);
    memoryStore.alerts.push(record);
    return record;
  }

  const created = await GuardAlert.create(payload);
  return created.toObject();
};
