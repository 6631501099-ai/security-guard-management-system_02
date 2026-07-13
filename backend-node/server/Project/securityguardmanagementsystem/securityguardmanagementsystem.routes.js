'use strict';

const express = require('express');
const router = express.Router();

const account = require('../accounts/service/account');
const authorization = require('../security/service/authorization');
const securityguardmanagementsystemDocument = require('./service/securityguardmanagementsystem_document');
const gpsRoutes = require('../gps/gps.routes');

const canViewRegistry = authorization.requirePermission('/security-guard-management-system/registry', 'view');
const canEditRegistry = authorization.requirePermission('/security-guard-management-system/registry', 'edit');
const canDeleteRegistry = authorization.requirePermission('/security-guard-management-system/registry', 'delete');
const canViewReports = authorization.requirePermission(['/security-guard-management-system/registry', '/security-guard-management-system/reports'], 'view');

function ok(response, data, status) {
  return response.status(status || 200).json({
    code: 20000,
    message: 'Success',
    data: data
  });
}

function fail(response, error) {
  const status = error && error.status ? error.status : 500;
  return response.status(status).json({
    code: status === 400 ? 40000 : 50000,
    message: error && error.message ? error.message : 'SecurityGuardManagementSystem request failed'
  });
}

router.use(account.onCheckAuthorization);
router.use('/gps', gpsRoutes);

router.get('/documents', canViewRegistry, async function (request, response) {
  try {
    return ok(response, await securityguardmanagementsystemDocument.list(request.query || {}));
  } catch (error) {
    return fail(response, error);
  }
});

router.get('/documents/stats', canViewReports, async function (request, response) {
  try {
    return ok(response, await securityguardmanagementsystemDocument.stats());
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/documents', canEditRegistry, async function (request, response) {
  try {
    return ok(response, await securityguardmanagementsystemDocument.create(request.body || {}, request), 201);
  } catch (error) {
    return fail(response, error);
  }
});

router.put('/documents/:id', canEditRegistry, async function (request, response) {
  try {
    return ok(response, await securityguardmanagementsystemDocument.update(request.params.id, request.body || {}, request));
  } catch (error) {
    return fail(response, error);
  }
});

router.delete('/documents/:id', canDeleteRegistry, async function (request, response) {
  try {
    return ok(response, await securityguardmanagementsystemDocument.remove(request.params.id));
  } catch (error) {
    return fail(response, error);
  }
});

router.post('/documents/seed-demo', canEditRegistry, async function (request, response) {
  try {
    return ok(response, await securityguardmanagementsystemDocument.seedDemo(request), 201);
  } catch (error) {
    return fail(response, error);
  }
});

module.exports = router;
