<template>
  <CSidebar
      class="bg-style1"
      :minimize="minimize"
      unfoldable
      :show="show"
      @update:show="(value) => $store.commit('set', ['sidebarShow', value])"
  >
    <CSidebarBrand class="d-md-down-none" >
<!--      <CIcon-->
<!--          class="c-sidebar-brand-full"-->
<!--          name="logo"-->
<!--          size="custom-size"-->
<!--          :height="35"-->
<!--          viewBox="0 0 556 134"-->
<!--      />-->
      <div class="c-sidebar-brand-full" >
        <a href="/">
          <CRow >
            <img class="pt-2 pb-2" src="@/assets/logo.svg" height="60px">
            <CCol class="text-white">
              <p class="font-weight-bold mb-0 mt-2 h5">MFU</p>
              <p class="font-weight-bold">{{ $t('common.app.dashboardSystem') }}</p>
            </CCol>
          </CRow>
        </a>

      </div>


      <!--      <img src="@/assets/logo.svg" height="48"/>-->
      <CIcon
          class="c-sidebar-brand-minimized"
          name="logo"
          size="custom-size"
          :height="35"
          viewBox="0 0 110 134"
      />
    </CSidebarBrand>
    <CRenderFunction flat :contentToRender="navs"/>
    <CSidebarMinimizer
        class="c-d-md-down-none"
        @click.native="$store.commit('toggle', 'sidebarMinimize')"
    />
  </CSidebar>
</template>

<script>
import buildNav from './_nav'

export default {
  name: 'TheSidebar',
  computed: {
    permissionLoaded() {
      return this.$store.getters['security/loaded']
    },
    navs() {
      this.$i18n.locale
      const navConfig = buildNav(this.$t.bind(this))
      return this.filterNavTree(navConfig)
    },
    show() {
      return this.$store.state.sidebarShow
    },
    minimize() {
      return this.$store.state.sidebarMinimize
    }
  },
  watch: {
    '$store.state.XAccessToken': {
      async handler(value) {
        if (!value) return
        if (this.permissionLoaded) return
        try {
          await this.$store.dispatch('security/fetchMyPermissions')
        } catch (error) {
          // Keep sidebar visible if permission bootstrap fails.
        }
      },
      immediate: true
    }
  },
  methods: {
    normalizePermissionPath(path) {
      if (!path) return ''
      let normalized = String(path).trim()
      const queryIndex = normalized.indexOf('?')
      if (queryIndex !== -1) normalized = normalized.slice(0, queryIndex)
      const hashIndex = normalized.indexOf('#')
      if (hashIndex !== -1) normalized = normalized.slice(0, hashIndex)
      normalized = normalized.replace(/\/{2,}/g, '/')
      if (!normalized.startsWith('/')) normalized = `/${normalized}`
      if (normalized.length > 1 && normalized.endsWith('/')) {
        normalized = normalized.slice(0, -1)
      }
      return normalized
    },
    swapPermissionPlurality(path) {
      const normalized = this.normalizePermissionPath(path)
      if (!normalized) return ''
      if (normalized.includes('/permissions')) return normalized.replace('/permissions', '/permission')
      if (normalized.includes('/permission')) return normalized.replace('/permission', '/permissions')
      return ''
    },
    permissionPaths(item) {
      const paths = []
      if (item && item.permission && item.permission.path) paths.push(item.permission.path)
      if (item && item.permission && Array.isArray(item.permission.paths)) {
        item.permission.paths.forEach(path => paths.push(path))
      }
      if (!paths.length && item) paths.push(item.to || item.route || '')
      return paths
        .map(this.normalizePermissionPath)
        .filter(Boolean)
    },
    hasViewPermission(item) {
      if (!item) return true
      const explicitPaths = this.permissionPaths(item)
      if (!this.permissionLoaded) {
        return !this.$store.state.XAccessToken
      }
      const matrix = this.$store.getters['security/matrix'] || {}
      const action = item.permission && item.permission.action ? item.permission.action : 'view'

      // ถ้า path ใดๆ ไม่ได้ลงทะเบียนใน Permission Matrix เลย → ถือว่าไม่มีการจำกัดสิทธิ์ → แสดงเมนู
      // จะซ่อนเฉพาะเมื่อ path อยู่ใน matrix แต่ user ไม่มีสิทธิ์เท่านั้น
      return explicitPaths.some(path => {
        const rule = matrix[path] || matrix[this.swapPermissionPlurality(path)]
        if (!rule) return true  // path ไม่ได้ register → แสดงเสมอ
        return !!(rule.all || rule[action] || rule.view)
      })
    },
    filterNavTree(items) {
      if (!Array.isArray(items)) return []

      const filtered = items.reduce((result, item) => {
        if (!item || typeof item !== 'object') return result

        if (item._name === 'CSidebarNavTitle') {
          result.push({ ...item })
          return result
        }

        const nextItem = { ...item }
        const children = Array.isArray(item._children) ? this.filterNavTree(item._children) : null
        const dropdownItems = Array.isArray(item.items) ? this.filterNavTree(item.items) : null

        if (children) nextItem._children = children
        if (dropdownItems) nextItem.items = dropdownItems

        const hasVisibleChildren = !!((children && children.length) || (dropdownItems && dropdownItems.length))

        if (hasVisibleChildren || this.hasViewPermission(item)) {
          result.push(nextItem)
        }

        return result
      }, [])

      return filtered.filter((item, index) => {
        if (item._name !== 'CSidebarNavTitle') return true
        const nextItem = filtered[index + 1]
        return !!nextItem && nextItem._name !== 'CSidebarNavTitle'
      })
    }
  }
}
</script>

<style>
/* Unified brand sidebar — same maroon identity used by the MFU Security module
   (see projects/views/mfusecurity/mfu-security-sidebar.shared.scss) so every
   section of the app shares one consistent look-and-feel. */
.bg-style1{
  background: linear-gradient(180deg, #6E0A0A 0%, #3A0000 100%);
}

.bg-style1 .c-sidebar-brand{
  background: transparent;
  border-bottom: 1px solid rgba(255,255,255,.14);
}

.bg-style1 .c-sidebar-nav-title{
  color: rgba(255,255,255,.55);
}

.bg-style1 .c-sidebar-nav-link,
.bg-style1 .c-sidebar-nav-dropdown-toggle{
  color: rgba(255,255,255,.88);
  border-radius: 12px;
  margin: 2px 10px;
  width: calc(100% - 20px);
}

.bg-style1 .c-sidebar-nav-link:hover,
.bg-style1 .c-sidebar-nav-dropdown-toggle:hover{
  background: rgba(255,255,255,.08);
  color: #fff;
}

.bg-style1 .c-sidebar-nav-link.c-active,
.bg-style1 .c-sidebar-nav-link.active,
.bg-style1 .c-sidebar-nav-dropdown.c-show > .c-sidebar-nav-dropdown-toggle{
  background: rgba(255,255,255,.16);
  color: #fff;
}

.bg-style1 .c-sidebar-nav-dropdown-items .c-sidebar-nav-link{
  background: rgba(0,0,0,.12);
}

.bg-style1 .c-sidebar-nav-icon{
  color: rgba(255,255,255,.85);
}

.bg-style1 .c-sidebar-minimizer{
  background: rgba(0,0,0,.15);
}
</style>
