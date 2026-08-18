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
  min-height: 70vh;
  background: #F5F7FB;
  border-radius: 16px;
  box-shadow: 0 6px 14px rgba(0, 0, 0, 0.05);
  overflow: hidden;
}

.mfu-security-layout__content {
  flex: 1;
  min-width: 0;
  padding: 20px;
  overflow-x: hidden;
}

@media (max-width: 768px) {
  .mfu-security-layout {
    flex-direction: column;
  }
}
</style>