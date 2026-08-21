<template>
  <div class="mfu-security-layout">
    <MfuSecuritySidebar />
    <div class="mfu-security-layout__content">
      <router-view />
    </div>
  </div>
</template>

<script>
import MfuSecuritySidebar from './MfuSecuritySidebar'

export default {
  name: 'MfuSecurityLayout',
  components: { MfuSecuritySidebar }
}
</script>

<style scoped lang="scss">
.mfu-security-layout {
  display: flex;
  align-items: stretch;
  min-height: 100vh;
  background: #F5F7FB;
  overflow: hidden;
}

.mfu-security-layout__content {
  flex: 1;
  min-width: 0;
  padding: 24px 28px;
  overflow-x: hidden;
  overflow-y: auto;
  max-height: 100vh;
}

@media (max-width: 768px) {
  .mfu-security-layout {
    flex-direction: column;
  }
}
</style>