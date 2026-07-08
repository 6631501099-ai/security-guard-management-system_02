'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const express = require('express');

const securityguardmanagementsystemConfig = require('../../../config/config');
const { createMockIamServer } = require('../../../test/mock-iam-server');

const ROUTER_PATH = path.resolve(__dirname, './accounts.routes');

let mockServer;
let appServer;

async function startHttpApp() {
  const router = require(ROUTER_PATH);
  const app = express();
  app.use(express.json());
  app.use('/api/v1', router);
  await new Promise(function (resolve) {
    appServer = app.listen(0, '127.0.0.1', resolve);
  });
  const address = appServer.address();
  return `http://127.0.0.1:${address.port}`;
}

async function stopHttpApp() {
  if (!appServer) return;
  await new Promise(function (resolve, reject) {
    appServer.close(function (error) {
      if (error) return reject(error);
      resolve();
    });
  });
  appServer = null;
}

async function requestJson(baseAppUrl, method, pathName, options) {
  const response = await fetch(`${baseAppUrl}${pathName}`, {
    method: method,
    headers: Object.assign({
      'Content-Type': 'application/json'
    }, options && options.headers ? options.headers : {}),
    body: options && Object.prototype.hasOwnProperty.call(options, 'body')
      ? JSON.stringify(options.body)
      : undefined
  });
  return {
    status: response.status,
    body: await response.json()
  };
}

function setSecurityGuardManagementSystemAccountAssignments(accountId) {
  mockServer.state.accountAssignments = [
    {
      _id: 'acct-assign-securityguardmanagementsystem',
      account: accountId || 'acc-1',
      group: { _id: 'group-2', name: 'Security Guard Management System Admin' },
      active: true,
      dataScope: 'org',
      scopeUnits: []
    }
  ];
}

function resetUserSession() {
  mockServer.state.userSessions = new Map([
    ['user-token-1', {
      account: {
        _id: 'acc-1',
        email: 'securityguardmanagementsystem.ops@example.com',
        status: { key: 'ACTIVE' },
        control: { device: [], trustedDevices: [] }
      },
      sessions: [{ _id: 'session-1', current: true }],
      trustedDevices: [{ _id: 'trusted-1', deviceId: 'browser-1' }]
    }]
  ]);
}

test.before(async function () {
  mockServer = createMockIamServer();
  const serverInfo = await mockServer.start();

  securityguardmanagementsystemConfig.iam.baseUrl = serverInfo.baseUrl;
  securityguardmanagementsystemConfig.iam.timeout = 5000;
  securityguardmanagementsystemConfig.iamAdmin.baseUrl = serverInfo.baseUrl;
  securityguardmanagementsystemConfig.iamAdmin.tokenPath = '/api/v1/b2b/token';
  securityguardmanagementsystemConfig.iamAdmin.basePath = '/api/v1/b2b/admin';
  securityguardmanagementsystemConfig.iamAdmin.clientId = 'security-guard-management-system-sdk';
  securityguardmanagementsystemConfig.iamAdmin.clientSecret = 'super-secret';
  securityguardmanagementsystemConfig.iamAdmin.scope = 'security.guard.management.system.registry.read security.guard.management.system.registry.write security.guard.management.system.report.read iam.security.read iam.security.write iam.audit.read iam.accounts.read';
  securityguardmanagementsystemConfig.iamAdmin.audience = 'securityguardmanagementsystem-api';
  securityguardmanagementsystemConfig.security.permissionSource = 'iam';
});

test.after(async function () {
  delete require.cache[ROUTER_PATH];
  await stopHttpApp();
  await mockServer.stop();
});

test.beforeEach(function () {
  resetUserSession();
});

test('accounts routes proxy signin and auth me to IAM', async function () {
  setSecurityGuardManagementSystemAccountAssignments('acc-1');
  delete require.cache[ROUTER_PATH];
  const appBaseUrl = await startHttpApp();

  const signinResult = await requestJson(appBaseUrl, 'POST', '/api/v1/signin', {
    body: { email: 'securityguardmanagementsystem.ops@example.com' }
  });
  assert.equal(signinResult.status, 200);
  assert.equal(signinResult.body.data.xAccessToken, 'user-token-1');

  const meResult = await requestJson(appBaseUrl, 'GET', '/api/v1/auth/me', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(meResult.status, 200);
  assert.equal(meResult.body.data._id, 'acc-1');

  await stopHttpApp();
});

test('accounts routes reject signin when account is not in securityguardmanagementsystem scope', async function () {
  mockServer.state.accountAssignments = [
    {
      _id: 'acct-assign-iam',
      account: 'acc-1',
      group: { _id: 'group-1', name: 'IAM Governance' },
      active: true,
      dataScope: 'org',
      scopeUnits: []
    }
  ];

  delete require.cache[ROUTER_PATH];
  const appBaseUrl = await startHttpApp();

  const signinResult = await requestJson(appBaseUrl, 'POST', '/api/v1/signin', {
    body: { email: 'securityguardmanagementsystem.ops@example.com' }
  });
  assert.equal(signinResult.status, 403);
  assert.equal(signinResult.body.error, 'account_not_in_securityguardmanagementsystem_scope');

  const meResult = await requestJson(appBaseUrl, 'GET', '/api/v1/auth/me', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(meResult.status, 404);

  await stopHttpApp();
});

test('accounts routes proxy account update to IAM after IAM-backed authorization', async function () {
  mockServer.state.permissionMatrix = {
    '/accounts/directory': { view: true, edit: true, action: true },
    '/accounts/lifecycle': { view: true, edit: true, action: true }
  };
  setSecurityGuardManagementSystemAccountAssignments('acc-1');

  delete require.cache[ROUTER_PATH];
  const appBaseUrl = await startHttpApp();

  const updateResult = await requestJson(appBaseUrl, 'PUT', '/api/v1/accounts/acc-1', {
    headers: {
      'x-access-token': 'user-token-1'
    },
    body: {
      email: 'securityguardmanagementsystem.updated@example.com'
    }
  });

  assert.equal(updateResult.status, 200);
  assert.equal(updateResult.body.data.email, 'securityguardmanagementsystem.updated@example.com');
  assert.equal(mockServer.state.accounts[0].email, 'securityguardmanagementsystem.updated@example.com');

  await stopHttpApp();
});

test('accounts routes expose only securityguardmanagementsystem assigned accounts', async function () {
  mockServer.state.permissionMatrix = {
    '/accounts/directory': { view: true, edit: true, action: true }
  };
  mockServer.state.accounts = [
    {
      _id: 'acc-1',
      email: 'securityguardmanagementsystem.ops@example.com',
      securityGroups: [
        { _id: 'group-1', title: [{ key: 'en', value: 'IAM Governance' }] },
        { _id: 'group-2', title: [{ key: 'en', value: 'Security Guard Management System Admin' }] }
      ]
    },
    { _id: 'acc-iam', email: 'iam.saksith.rit@mfu.ac.th' }
  ];
  mockServer.state.accountAssignments = [
    {
      _id: 'acct-assign-securityguardmanagementsystem',
      account: { _id: 'acc-1', email: 'securityguardmanagementsystem.ops@example.com' },
      group: { _id: 'group-2', name: 'Security Guard Management System Admin' },
      active: true,
      dataScope: 'org',
      scopeUnits: []
    },
    {
      _id: 'acct-assign-iam',
      account: 'acc-iam',
      group: { _id: 'group-1', name: 'IAM Governance' },
      active: true,
      dataScope: 'org',
      scopeUnits: []
    }
  ];

  delete require.cache[ROUTER_PATH];
  const appBaseUrl = await startHttpApp();

  const accountsResult = await requestJson(appBaseUrl, 'GET', '/api/v1/accounts', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(accountsResult.status, 200);
  assert.deepEqual(
    accountsResult.body.data.map(function (item) { return item.email; }),
    ['securityguardmanagementsystem.ops@example.com']
  );
  assert.deepEqual(
    accountsResult.body.data[0].securityGroups.map(function (item) { return item && item._id; }),
    ['group-2']
  );

  const updateIamAccountResult = await requestJson(appBaseUrl, 'PUT', '/api/v1/accounts/acc-iam', {
    headers: {
      'x-access-token': 'user-token-1'
    },
    body: {
      email: 'iam.updated@example.com'
    }
  });
  assert.equal(updateIamAccountResult.status, 404);
  assert.equal(updateIamAccountResult.body.error, 'account_not_in_securityguardmanagementsystem_scope');
  assert.equal(mockServer.state.accounts[1].email, 'iam.saksith.rit@mfu.ac.th');

  await stopHttpApp();
});

test('accounts routes remove only securityguardmanagementsystem access from account', async function () {
  mockServer.state.permissionMatrix = {
    '/accounts/directory': { view: true, edit: true, action: true }
  };
  mockServer.state.accounts = [
    { _id: 'acc-1', email: 'securityguardmanagementsystem.ops@example.com' }
  ];
  mockServer.state.accountAssignments = [
    {
      _id: 'acct-assign-securityguardmanagementsystem',
      account: { _id: 'acc-1', email: 'securityguardmanagementsystem.ops@example.com' },
      group: { _id: 'group-2', name: 'Security Guard Management System Admin' },
      active: true,
      dataScope: 'org',
      scopeUnits: []
    },
    {
      _id: 'acct-assign-iam',
      account: { _id: 'acc-1', email: 'securityguardmanagementsystem.ops@example.com' },
      group: { _id: 'group-1', name: 'IAM Governance' },
      active: true,
      dataScope: 'org',
      scopeUnits: []
    }
  ];

  delete require.cache[ROUTER_PATH];
  const appBaseUrl = await startHttpApp();

  const removeResult = await requestJson(appBaseUrl, 'DELETE', '/api/v1/accounts/acc-1/securityguardmanagementsystem-access', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(removeResult.status, 200);
  assert.equal(removeResult.body.data.removed, 1);
  assert.deepEqual(
    mockServer.state.accountAssignments.map(function (item) { return item._id; }),
    ['acct-assign-iam']
  );

  const accountsResult = await requestJson(appBaseUrl, 'GET', '/api/v1/accounts', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(accountsResult.status, 200);
  assert.deepEqual(accountsResult.body.data, []);

  await stopHttpApp();
});

test('accounts routes invite account into securityguardmanagementsystem scope', async function () {
  mockServer.state.permissionMatrix = {
    '/accounts/directory': { view: true, edit: true, action: true }
  };
  mockServer.state.accounts = [
    { _id: 'acc-1', email: 'securityguardmanagementsystem.ops@example.com' }
  ];
  mockServer.state.accountAssignments = [];

  delete require.cache[ROUTER_PATH];
  const appBaseUrl = await startHttpApp();

  const inviteResult = await requestJson(appBaseUrl, 'POST', '/api/v1/accounts/invite', {
    headers: {
      'x-access-token': 'user-token-1'
    },
    body: {
      email: 'new.securityguardmanagementsystem@example.com',
      firstName: 'New',
      lastName: 'SecurityGuardManagementSystem',
      groupIds: ['group-2', 'group-1']
    }
  });
  assert.equal(inviteResult.status, 201);
  assert.equal(inviteResult.body.data.account.email, 'new.securityguardmanagementsystem@example.com');
  assert.deepEqual(
    inviteResult.body.data.groups.map(function (item) { return item && item._id; }),
    ['group-2']
  );
  assert.equal(mockServer.state.accountAssignments.some(function (item) {
    return item.group && item.group._id === 'group-1';
  }), false);

  const accountsResult = await requestJson(appBaseUrl, 'GET', '/api/v1/accounts', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(accountsResult.status, 200);
  assert.deepEqual(
    accountsResult.body.data.map(function (item) { return item.email; }),
    ['new.securityguardmanagementsystem@example.com']
  );

  await stopHttpApp();
});

test('accounts routes expose only securityguardmanagementsystem scoped sessions and trusted devices', async function () {
  mockServer.state.permissionMatrix = {
    '/accounts/directory': { view: true, edit: true, action: true }
  };
  setSecurityGuardManagementSystemAccountAssignments('acc-1');
  const session = mockServer.state.userSessions.get('user-token-1');
  session.sessions = [
    {
      _id: 'securityguardmanagementsystem-session',
      deviceId: 'securityguardmanagementsystem-browser',
      clientId: 'security-guard-management-system-sdk',
      audience: 'securityguardmanagementsystem-api',
      system: 'securityguardmanagementsystem'
    },
    {
      _id: 'iam-session',
      deviceId: 'iam-browser',
      clientId: 'iam-console',
      audience: 'iam-admin-api',
      system: 'iam'
    }
  ];
  session.trustedDevices = [
    {
      _id: 'securityguardmanagementsystem-device',
      deviceId: 'securityguardmanagementsystem-browser',
      clientId: 'security-guard-management-system-sdk',
      audience: 'securityguardmanagementsystem-api',
      system: 'securityguardmanagementsystem'
    },
    {
      _id: 'iam-device',
      deviceId: 'iam-browser',
      clientId: 'iam-console',
      audience: 'iam-admin-api',
      system: 'iam'
    }
  ];

  delete require.cache[ROUTER_PATH];
  const appBaseUrl = await startHttpApp();

  const sessionsResult = await requestJson(appBaseUrl, 'GET', '/api/v1/accounts/acc-1/sessions', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(sessionsResult.status, 200);
  assert.deepEqual(
    sessionsResult.body.data.sessions.map(function (item) { return item._id; }),
    ['securityguardmanagementsystem-session']
  );

  const devicesResult = await requestJson(appBaseUrl, 'GET', '/api/v1/accounts/acc-1/trusted-devices', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(devicesResult.status, 200);
  assert.deepEqual(
    devicesResult.body.data.trustedDevices.map(function (item) { return item._id; }),
    ['securityguardmanagementsystem-device']
  );

  await stopHttpApp();
});

test('accounts routes revoke only securityguardmanagementsystem scoped sessions and trusted devices', async function () {
  mockServer.state.permissionMatrix = {
    '/accounts/directory': { view: true, edit: true, action: true }
  };
  setSecurityGuardManagementSystemAccountAssignments('acc-1');
  const session = mockServer.state.userSessions.get('user-token-1');
  session.sessions = [
    {
      _id: 'securityguardmanagementsystem-session',
      deviceId: 'securityguardmanagementsystem-browser',
      clientId: 'security-guard-management-system-sdk',
      audience: 'securityguardmanagementsystem-api',
      system: 'securityguardmanagementsystem'
    },
    {
      _id: 'shared-id',
      deviceId: 'iam-browser',
      clientId: 'iam-console',
      audience: 'iam-admin-api',
      system: 'iam'
    }
  ];
  session.trustedDevices = [
    {
      _id: 'securityguardmanagementsystem-device',
      deviceId: 'securityguardmanagementsystem-browser',
      clientId: 'security-guard-management-system-sdk',
      audience: 'securityguardmanagementsystem-api',
      system: 'securityguardmanagementsystem'
    },
    {
      _id: 'shared-device-id',
      deviceId: 'iam-browser',
      clientId: 'iam-console',
      audience: 'iam-admin-api',
      system: 'iam'
    }
  ];

  delete require.cache[ROUTER_PATH];
  const appBaseUrl = await startHttpApp();

  const revokeSessionResult = await requestJson(appBaseUrl, 'DELETE', '/api/v1/accounts/acc-1/sessions/securityguardmanagementsystem-session', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(revokeSessionResult.status, 200);
  assert.equal(session.sessions.some(function (item) { return item._id === 'securityguardmanagementsystem-session'; }), false);
  assert.equal(session.sessions.some(function (item) { return item._id === 'shared-id'; }), true);

  const revokeDeviceResult = await requestJson(appBaseUrl, 'DELETE', '/api/v1/accounts/acc-1/trusted-devices/securityguardmanagementsystem-device', {
    headers: {
      'x-access-token': 'user-token-1'
    }
  });
  assert.equal(revokeDeviceResult.status, 200);
  assert.equal(session.trustedDevices.some(function (item) { return item._id === 'securityguardmanagementsystem-device'; }), false);
  assert.equal(session.trustedDevices.some(function (item) { return item._id === 'shared-device-id'; }), true);

  await stopHttpApp();
});
