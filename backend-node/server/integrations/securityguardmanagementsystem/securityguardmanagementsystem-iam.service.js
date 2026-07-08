'use strict';

const { createProjectIamService } = require('../iam/project-iam-service');
const { normalizeAudience, normalizeScope } = require('../iam/iam-sdk-adapter');

const DEFAULT_SECURITY_GUARD_MANAGEMENT_SYSTEM_SCOPES = [
  'security.guard.management.system.registry.read',
  'security.guard.management.system.registry.write',
  'security.guard.management.system.report.read',
  'iam.security.read',
  'iam.security.write',
  'iam.audit.read',
  'iam.accounts.read'
];

function applySecurityGuardManagementSystemDefaults(payload) {
  const source = payload || {};
  const metadata = Object.assign({}, source.metadata || {});

  const targetSystem = String(source.targetSystem || metadata.targetSystem || 'securityguardmanagementsystem').trim();
  const ownerEmail = String(source.ownerEmail || metadata.ownerEmail || 'security-guard-management-system.integration@example.com').trim();
  const partnerId = String(source.partnerId || metadata.partnerId || 'security-guard-management-system-team').trim();
  const tenant = String(source.tenant || metadata.tenant || 'iam-shared').trim();
  const systemCode = source.systemCode || metadata.systemCode || null;

  return Object.assign({}, source, {
    targetSystem: targetSystem,
    ownerEmail: ownerEmail,
    partnerId: partnerId,
    tenant: tenant,
    allowedScopes: normalizeScope(source.allowedScopes || metadata.allowedScopes || DEFAULT_SECURITY_GUARD_MANAGEMENT_SYSTEM_SCOPES),
    allowedAudiences: normalizeAudience(source.allowedAudiences || metadata.allowedAudiences || 'securityguardmanagementsystem-api'),
    metadata: Object.assign({}, metadata, systemCode ? {
      systemCode: String(systemCode).trim()
    } : {}, {
      targetSystem: targetSystem,
      ownerEmail: ownerEmail,
      partnerId: partnerId,
      tenant: tenant
    })
  });
}

function createSecurityGuardManagementSystemIamService(config) {
  const projectIamService = createProjectIamService(config);

  return Object.assign({}, projectIamService, {
    async registerManagedClient(payload, options) {
      return projectIamService.registerManagedClient(applySecurityGuardManagementSystemDefaults(payload), options || {});
    },
    async updateManagedClient(payload, options) {
      return projectIamService.updateManagedClient(applySecurityGuardManagementSystemDefaults(payload), options || {});
    }
  });
}

module.exports = {
  createSecurityGuardManagementSystemIamService: createSecurityGuardManagementSystemIamService
};
