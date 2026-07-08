<template>
  <div class="dashboard-page">
    <CRow>
      <CCol lg="8" class="mb-4">
        <CCard class="h-100 dashboard-card">
          <CCardBody>
            <div class="dashboard-kicker">{{ $t('securityguardmanagementsystemDashboard.kicker') }}</div>
            <h2 class="dashboard-title">{{ $t('securityguardmanagementsystemDashboard.title') }}</h2>
            <p class="dashboard-text">{{ $t('securityguardmanagementsystemDashboard.subtitle') }}</p>

            <div class="dashboard-actions">
              <router-link class="btn btn-primary" to="/security-guard-management-system/registry">
                {{ $t('securityguardmanagementsystemDashboard.actions.openRegistry') }}
              </router-link>
            </div>
          </CCardBody>
        </CCard>
      </CCol>

      <CCol lg="4" class="mb-4">
        <CCard class="h-100 dashboard-card">
          <CCardBody>
            <div class="dashboard-kicker">{{ $t('securityguardmanagementsystemDashboard.scopeTitle') }}</div>
            <h4 class="dashboard-subtitle">{{ $t('securityguardmanagementsystemDashboard.scopeHeading') }}</h4>
            <ul class="dashboard-list">
              <li>{{ $t('securityguardmanagementsystemDashboard.scopeItems.signIn') }}</li>
              <li>{{ $t('securityguardmanagementsystemDashboard.scopeItems.delegatedPermission') }}</li>
              <li>{{ $t('securityguardmanagementsystemDashboard.scopeItems.accountDirectory') }}</li>
              <li>{{ $t('securityguardmanagementsystemDashboard.scopeItems.securityguardmanagementsystemRegistry') }}</li>
            </ul>
          </CCardBody>
        </CCard>
      </CCol>
    </CRow>

    <CRow>
      <CCol md="4" class="mb-4">
        <CCard class="dashboard-card h-100">
          <CCardBody>
            <div class="dashboard-stat__label">{{ $t('securityguardmanagementsystemDashboard.cards.identity.label') }}</div>
            <div class="dashboard-stat__value">{{ $t('securityguardmanagementsystemDashboard.cards.identity.value') }}</div>
            <div class="dashboard-stat__hint">{{ $t('securityguardmanagementsystemDashboard.cards.identity.hint') }}</div>
          </CCardBody>
        </CCard>
      </CCol>

      <CCol md="4" class="mb-4">
        <CCard class="dashboard-card h-100">
          <CCardBody>
            <div class="dashboard-stat__label">{{ $t('securityguardmanagementsystemDashboard.cards.apiFlow.label') }}</div>
            <div class="dashboard-stat__value">{{ $t('securityguardmanagementsystemDashboard.cards.apiFlow.value') }}</div>
            <div class="dashboard-stat__hint">{{ $t('securityguardmanagementsystemDashboard.cards.apiFlow.hint') }}</div>
          </CCardBody>
        </CCard>
      </CCol>

      <CCol md="4" class="mb-4">
        <CCard class="dashboard-card h-100">
          <CCardBody>
            <div class="dashboard-stat__label">{{ $t('securityguardmanagementsystemDashboard.cards.owner.label') }}</div>
            <div class="dashboard-stat__value">{{ $t('securityguardmanagementsystemDashboard.cards.owner.value') }}</div>
            <div class="dashboard-stat__hint">{{ $t('securityguardmanagementsystemDashboard.cards.owner.hint') }}</div>
          </CCardBody>
        </CCard>
      </CCol>
    </CRow>
  </div>
</template>

<script>
export default {
  name: 'Dashboard'
}
</script>

<style scoped>
.dashboard-page {
  padding: 0.25rem;
}

.dashboard-card {
  border: 0;
  box-shadow: 0 18px 40px rgba(15, 23, 42, 0.08);
}

.dashboard-kicker {
  margin-bottom: 0.75rem;
  color: #64748b;
  font-size: 0.8rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.dashboard-title {
  margin-bottom: 0.75rem;
  color: #0f172a;
  font-size: 2rem;
  font-weight: 700;
}

.dashboard-subtitle {
  margin-bottom: 0.75rem;
  color: #0f172a;
  font-weight: 700;
}

.dashboard-text,
.dashboard-stat__hint {
  color: #475569;
  line-height: 1.6;
}

.dashboard-actions {
  margin-top: 1.5rem;
}

.dashboard-list {
  margin: 0;
  padding-left: 1.25rem;
  color: #334155;
  line-height: 1.8;
}

.dashboard-stat__label {
  color: #64748b;
  font-size: 0.8rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.dashboard-stat__value {
  margin: 0.5rem 0;
  color: #0f172a;
  font-size: 1.5rem;
  font-weight: 700;
}
</style>
