<template>
  <aside class="mfu-sidebar" :class="{ 'is-collapsed': collapsed }">
    <button class="mfu-sidebar__collapse-btn" type="button" @click="collapsed = !collapsed" title="ย่อ/ขยายเมนู">
      <CIcon :name="collapsed ? 'cil-chevron-right' : 'cil-chevron-left'" />
    </button>

    <div class="mfu-sidebar__brand">
      <div class="mfu-sidebar__brand-icon">
        <CIcon name="cil-shield-alt" />
      </div>
      <span class="mfu-sidebar__brand-text">MFU SECURITY</span>
    </div>

    <nav class="mfu-sidebar__nav">
      <router-link
        v-for="item in navItems"
        :key="item.to"
        :to="item.to"
        class="mfu-sidebar__nav-item"
        active-class="is-active"
      >
        <CIcon :name="item.icon" class="mfu-sidebar__nav-icon" />
        <span class="mfu-sidebar__nav-label">{{ item.label }}</span>
      </router-link>
    </nav>

    <button class="mfu-sidebar__logout" type="button" @click="onLogout">
      <CIcon name="cil-account-logout" />
      <span class="mfu-sidebar__nav-label">ออกจากระบบ</span>
    </button>
  </aside>
</template>

<script>
export default {
  name: 'MfuSecuritySidebar',
  data () {
    return {
      collapsed: false,
      navItems: [
        { to: '/mfu-security/overview', label: 'ภาพรวม', icon: 'cil-grid' },
        { to: '/mfu-security/tracking', label: 'ติดตามพิกัดสด', icon: 'cil-location-pin' },
        { to: '/mfu-security/sos', label: 'แจ้งเตือนฉุกเฉิน SOS', icon: 'cil-warning' },
        { to: '/mfu-security/guards', label: 'รายชื่อการ์ด', icon: 'cil-people' },
        { to: '/mfu-security/schedule', label: 'ตารางงาน', icon: 'cil-calendar' },
        { to: '/mfu-security/tasks', label: 'มอบหมายงาน', icon: 'cil-clipboard' },
        { to: '/mfu-security/incidents', label: 'รายงานเหตุการณ์', icon: 'cil-description' },
        { to: '/mfu-security/logs', label: 'บันทึกล่าสุด', icon: 'cil-history' }
      ]
    }
  },
  methods: {
    async onLogout () {
      await this.$store.dispatch('auth/signOut')
      this.$router.push('/pages/login')
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security-sidebar.shared.scss";
</style>