'use strict';

const mongoose = require('mongoose');

const schema = new mongoose.Schema({
  guardId: { type: String, default: null, trim: true },
  deviceId: { type: String, default: null, trim: true },
  deviceName: { type: String, default: null, trim: true },
  coordinates: {
    latitude: { type: Number, required: true },
    longitude: { type: Number, required: true }
  },
  accuracy: { type: Number, default: null },
  batteryLevel: { type: Number, default: null },
  speed: { type: Number, default: null },
  heading: { type: Number, default: null },
  capturedAt: { type: Date, default: Date.now },
  lastSeenAt: { type: Date, default: Date.now },
  source: { type: String, default: 'device' },
  status: { type: String, default: 'active' }
}, { timestamps: true });

module.exports = mongoose.model('GpsGuardLocation', schema);
