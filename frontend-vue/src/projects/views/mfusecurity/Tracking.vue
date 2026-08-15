<template>
  <div class="mfu-security">
    <div class="row-top">
      <div class="section-title">ติดตามพิกัดสด</div>
      <div class="search-field" style="width:220px;">
        <CIcon name="cil-search" />
        <input v-model.trim="search" placeholder="ค้นหาการ์ด" />
      </div>
    </div>

    <div class="map-card" ref="mapCard">
      <div class="map-surface">
        <div class="map-block" style="left:6%;top:10%;width:20%;height:22%;"></div>
        <div class="map-block" style="left:30%;top:8%;width:15%;height:16%;"></div>
        <div class="map-block" style="left:6%;top:42%;width:26%;height:30%;"></div>
        <div class="map-block" style="left:50%;top:12%;width:32%;height:20%;"></div>
        <div class="map-block" style="left:50%;top:40%;width:16%;height:34%;"></div>
        <div class="map-block" style="left:70%;top:40%;width:15%;height:16%;"></div>
      </div>
      <div
        v-for="guard in filteredGuards"
        :key="guard.id"
        class="pin"
        :class="guard.status === 'out_of_scope' ? 'alert' : 'ok'"
        :style="pinStyle(guard)"
      >
        <div class="dot">
          <CIcon v-if="guard.status === 'out_of_scope'" name="cil-warning" style="color:#fff" />
          <CIcon v-else name="cil-circle" style="color:#fff" />
        </div>
        <div class="tag">{{ guard.name }}<template v-if="guard.status === 'out_of_scope'"> — นอกพื้นที่</template></div>
      </div>
      <button class="fab" title="เต็มจอ" @click="toggleFullscreen">
        <CIcon name="cil-fullscreen" />
      </button>
    </div>
  </div>
</template>

<script>
import { subscribeCollection, COLLECTIONS } from '@/service/firebase'

// Bounding box the demo campus map is drawn against — adjust to match real coordinates.
const BOUNDS = { minLat: 20.036, maxLat: 20.050, minLng: 99.888, maxLng: 99.902 }

export default {
  name: 'MfuSecurityTracking',
  data () {
    return {
      search: '',
      guards: [],
      unsubscribe: null
    }
  },
  computed: {
    filteredGuards () {
      if (!this.search) return this.guards
      const q = this.search.toLowerCase()
      return this.guards.filter(g => (g.name || '').toLowerCase().includes(q))
    }
  },
  mounted () {
    this.unsubscribe = subscribeCollection(COLLECTIONS.GUARDS, rows => { this.guards = rows })
  },
  beforeDestroy () {
    if (this.unsubscribe) this.unsubscribe()
  },
  methods: {
    pinStyle (guard) {
      const lat = Number(guard.lat)
      const lng = Number(guard.lng)
      if (Number.isNaN(lat) || Number.isNaN(lng)) return { left: '50%', top: '50%' }
      const leftPct = ((lng - BOUNDS.minLng) / (BOUNDS.maxLng - BOUNDS.minLng)) * 100
      const topPct = ((BOUNDS.maxLat - lat) / (BOUNDS.maxLat - BOUNDS.minLat)) * 100
      const clamp = v => Math.min(95, Math.max(5, v))
      return { left: clamp(leftPct) + '%', top: clamp(topPct) + '%' }
    },
    toggleFullscreen () {
      const el = this.$refs.mapCard
      if (!document.fullscreenElement) {
        if (el && el.requestFullscreen) el.requestFullscreen()
      } else if (document.exitFullscreen) {
        document.exitFullscreen()
      }
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
