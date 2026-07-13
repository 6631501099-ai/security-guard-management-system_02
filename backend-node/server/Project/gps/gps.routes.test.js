'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const gpsTrackerService = require('./service/gps-tracker.service');

function buildLocationPayload(suffix) {
  return {
    guardId: 'guard-001-' + suffix,
    deviceId: 'tracker-001-' + suffix,
    coordinates: { latitude: 13.7563, longitude: 100.5018 },
    capturedAt: new Date().toISOString(),
    source: 'device'
  };
}

test('gps tracker service stores a valid location payload', async function () {
  const created = await gpsTrackerService.createLocation(buildLocationPayload('valid'));
  assert.equal(created.guardId, 'guard-001-valid');
  assert.equal(created.deviceId, 'tracker-001-valid');
  assert.ok(created.coordinates && created.coordinates.latitude === 13.7563);
});

test('gps tracker service rejects invalid coordinates', async function () {
  await assert.rejects(async function () {
    await gpsTrackerService.createLocation({
      guardId: 'guard-002',
      deviceId: 'tracker-002',
      coordinates: { latitude: 100, longitude: 200 }
    });
  }, /Invalid coordinates/);
});
