'use strict';

const express = require('express');
const router = express.Router();

const account = require('../accounts/service/account');
const authorization = require('../security/service/authorization');
const gpsTrackerService = require('./service/gps-tracker.service');

const canViewTracking = authorization.requirePermission('/security-guard-management-system/registry', 'view');
const canEditTracking = authorization.requirePermission('/security-guard-management-system/registry', 'edit');

function ok(response, data, status) {
  return response.status(status || 200).json({
    code: 20000,
    message: 'Success',
    data
  });
}

function fail(response, error) {
  const status = error && error.status ? error.status : 500;
  return response.status(status).json({
    code: status === 400 ? 40000 : 50000,
    message: error && error.message ? error.message : 'GPS tracking request failed'
  });
}

router.use(account.onCheckAuthorization);

router.post('/locations', canEditTracking, async function (request, response) {
  try {
    return ok(response, await gpsTrackerService.createLocation(request.body || {}), 201);
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/guards/live', canViewTracking, async function (request, response) {
  try {
    return ok(response, await gpsTrackerService.listLiveGuards(request.query || {}));
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/guards/:guardId/history', canViewTracking, async function (request, response) {
  try {
    return ok(response, await gpsTrackerService.listHistory(request.params.guardId, request.query || {}));
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/alerts', canViewTracking, async function (request, response) {
  try {
    return ok(response, await gpsTrackerService.listAlerts(request.query || {}));
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/alerts', canEditTracking, async function (request, response) {
  try {
    return ok(response, await gpsTrackerService.createAlert(request.body || {}), 201);
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/health', canViewTracking, async function (request, response) {
  try {
    return ok(response, { status: 'ready' });
  } catch (error) {
    return fail(response, error);
  }
});

module.exports = router;
