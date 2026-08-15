export const LANDING_PATH_CANDIDATES = [
  '/dashboard',
  '/security-guard-management-system/registry',
  '/mfu-security/overview',
  '/operations/business',
  '/accounts/directory',
  '/security/permissions/menu',
  '/security/permissions/group',
  '/security/permissions/matrix',
  '/config/email-notifications'
]

export function resolveFirstAccessiblePath(canAccess, fallback = '/dashboard') {
  if (typeof canAccess !== 'function') return fallback
  const found = LANDING_PATH_CANDIDATES.find(path => canAccess(path, 'view'))
  return found || fallback
}
