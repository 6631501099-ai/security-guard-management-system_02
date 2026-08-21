<template>
  <div class="mfu-security">
    <div class="row-top">
      <div class="section-title">ติดตามพิกัดสด</div>
      <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;">
        <!-- Map Layer Switcher -->
        <div class="mode-switcher">
          <button
            class="mode-btn"
            :class="{ active: mapProvider === 'google_roadmap' }"
            @click="setTileProvider('google_roadmap')"
          >
            🗺️ Google Maps
          </button>
          <button
            class="mode-btn"
            :class="{ active: mapProvider === 'google_satellite' }"
            @click="setTileProvider('google_satellite')"
          >
            🛰️ Google ดาวเทียม
          </button>
          <button
            class="mode-btn"
            :class="{ active: mapProvider === 'osm' }"
            @click="setTileProvider('osm')"
          >
            🌐 OpenStreetMap
          </button>
        </div>

        <!-- Firebase connection status -->
        <div class="fb-status" :class="fbStatusClass" :title="fbStatusTitle">
          <span class="fb-dot"></span>
          <span class="fb-label">{{ fbStatusLabel }}</span>
        </div>
        <div class="search-field" style="width:200px;">
          <CIcon name="cil-search" />
          <input v-model.trim="search" placeholder="ค้นหาการ์ด..." />
        </div>
      </div>
    </div>

    <!-- Stats bar -->
    <div style="display:flex;gap:10px;margin-bottom:12px;flex-wrap:wrap;">
      <div class="stat-mini">
        <span class="dot-green"></span>
        การ์ดออนไลน์: <strong>{{ onlineGuards.length }}</strong>
      </div>
      <div class="stat-mini">
        <span class="dot-red"></span>
        นอกพื้นที่: <strong>{{ outOfScopeCount }}</strong>
      </div>
      <div class="stat-mini" style="color:var(--text-secondary);font-size:12px;">
        ทั้งหมดใน Firestore: {{ guards.length }} records
      </div>
    </div>

    <div class="map-card" ref="mapCard">
      <!-- Loading overlay -->
      <div v-if="loading" class="map-loading">
        <div class="spinner"></div>
        <p>กำลังเชื่อมต่อ Firebase...</p>
      </div>

      <!-- Firebase error -->
      <div v-else-if="firebaseError" class="map-loading map-error">
        <CIcon name="cil-warning" style="width:40px;height:40px;color:var(--accent-red)" />
        <p style="color:var(--accent-red);font-weight:700;margin:8px 0 4px;">Firebase เชื่อมต่อไม่ได้</p>
        <p style="font-size:13px;color:var(--text-secondary);">{{ firebaseError }}</p>

        <!-- Firebase Auth Login Form -->
        <div v-if="isPermissionError" style="margin-top:14px;background:#fff;padding:16px;border-radius:12px;box-shadow:0 4px 12px rgba(0,0,0,0.1);max-width:320px;width:100%;">
          <p style="font-size:13px;font-weight:700;color:var(--text-primary);margin:0 0 10px;">เข้าสู่ระบบ Firebase เพื่อเปิดใช้งานสิทธิ์</p>
          <input v-model.trim="fbEmail" type="email" placeholder="อีเมล Firebase" class="select-field" style="height:38px;font-size:13px;margin-bottom:8px;" />
          <input v-model="fbPass" type="password" placeholder="รหัสผ่าน" class="select-field" style="height:38px;font-size:13px;margin-bottom:10px;" />
          <button class="btn-filled btn-primarydark" style="width:100%;height:38px;justify-content:center;font-size:13px;" :disabled="loggingIn" @click="handleFbLogin">
            {{ loggingIn ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ Firebase' }}
          </button>
          <p v-if="loginError" style="font-size:12px;color:var(--accent-red);margin:8px 0 0;">{{ loginError }}</p>
        </div>
      </div>

      <!-- No guards online -->
      <div v-else-if="!loading && !firebaseError && onlineGuards.length === 0" class="map-empty-overlay">
        <CIcon name="cil-location-pin" style="width:32px;height:32px;color:var(--text-secondary)" />
        <p style="margin:8px 0 0;font-size:14px;color:var(--text-secondary);">
          ไม่มีเจ้าหน้าที่การ์ดออนไลน์ขณะนี้<br>
          <span style="font-size:12px;">(การ์ดต้องเช็คอินผ่านแอปมือถือภายใน 60 วินาที)</span>
        </p>
      </div>

      <!-- MAP LEAFLET CONTAINER -->
      <div id="leaflet-tracking-map" class="leaflet-map-surface"></div>

      <button class="fab" title="เต็มจอ" @click="toggleFullscreen">
        <CIcon name="cil-fullscreen" />
      </button>
    </div>

    <!-- Guard detail sheet -->
    <div class="overlay" :class="{ show: !!selectedGuard }" @click.self="selectedGuard = null">
      <div class="sheet" v-if="selectedGuard">
        <div class="sheet-handle"></div>
        <div class="sheet-title-row">
          <CIcon name="cil-shield-alt" />
          <h3>{{ selectedGuard.name }}</h3>
        </div>
        <div class="drow"><div class="k">สถานะ</div><div class="v">{{ selectedGuard.status === 'out_of_scope' ? 'นอกพื้นที่' : 'ในพื้นที่' }}</div></div>
        <div class="drow"><div class="k">ละติจูด</div><div class="v">{{ selectedGuard.lat }}</div></div>
        <div class="drow"><div class="k">ลองจิจูด</div><div class="v">{{ selectedGuard.lng }}</div></div>
        <div class="sheet-actions">
          <button class="action-btn" style="background:var(--primary-dark)" @click="flyToSelectedGuard">
            <CIcon name="cil-location-pin" />ไปที่ตำแหน่งการ์ด
          </button>
          <button class="action-btn" style="background:var(--info)" @click="selectedGuard = null">
            <CIcon name="cil-x" />ปิด
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { subscribeCollection, isGuardOnline, COLLECTIONS, loginFirebase } from '@/service/firebase'

const TILE_URLS = {
  google_roadmap: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
  google_satellite: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
  osm: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png'
}

function loadLeaflet () {
  return new Promise((resolve) => {
    if (window.L) { resolve(window.L); return }
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
    document.head.appendChild(link)
    const script = document.createElement('script')
    script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
    script.onload = () => resolve(window.L)
    document.head.appendChild(script)
  })
}

function mapGuard (row) {
  return Object.assign({}, row, {
    status: row.outOfScope === true ? 'out_of_scope' : 'on_route'
  })
}

export default {
  name: 'MfuSecurityTracking',
  data () {
    return {
      search: '',
      guards: [],
      unsubscribe: null,
      loading: true,
      firebaseError: '',
      selectedGuard: null,
      fbEmail: '',
      fbPass: '',
      loggingIn: false,
      loginError: '',
      mapProvider: 'google_roadmap', // 'google_roadmap', 'google_satellite', 'osm'
      leafletMap: null,
      leafletTileLayer: null,
      leafletMarkers: {},
      L: null
    }
  },
  computed: {
    isPermissionError () {
      return (this.firebaseError || '').toLowerCase().includes('permission') || (this.firebaseError || '').includes('สิทธิ์')
    },
    onlineGuards () {
      return this.guards.filter(isGuardOnline).map(mapGuard)
    },
    filteredGuards () {
      if (!this.search) return this.onlineGuards
      const q = this.search.toLowerCase()
      return this.onlineGuards.filter(g => (g.name || '').toLowerCase().includes(q))
    },
    outOfScopeCount () {
      return this.onlineGuards.filter(g => g.status === 'out_of_scope').length
    },
    fbStatusClass () {
      if (this.loading) return 'fb-connecting'
      if (this.firebaseError) return 'fb-error'
      return 'fb-connected'
    },
    fbStatusLabel () {
      if (this.loading) return 'กำลังเชื่อมต่อ...'
      if (this.firebaseError) return 'เชื่อมต่อล้มเหลว'
      return 'Firebase เชื่อมต่อแล้ว'
    },
    fbStatusTitle () {
      if (this.firebaseError) return this.firebaseError
      return ''
    }
  },
  watch: {
    filteredGuards: {
      handler () {
        this.updateLeafletMarkers()
      },
      deep: true
    }
  },
  async mounted () {
    try {
      this.unsubscribe = subscribeCollection(
        COLLECTIONS.GUARDS,
        rows => {
          this.guards = rows
          this.loading = false
          this.firebaseError = ''
          this.updateLeafletMarkers()
        },
        {
          onError: err => {
            this.loading = false
            this.firebaseError = (err && err.message) ? err.message : 'ไม่สามารถเชื่อมต่อ Firebase ได้'
          }
        }
      )
      this._fbTimeout = setTimeout(() => {
        if (this.loading) {
          this.loading = false
          this.firebaseError = 'ไม่ได้รับข้อมูลจาก Firebase ภายใน 8 วินาที'
        }
      }, 8000)

      this.L = await loadLeaflet()
      this.$nextTick(() => {
        this.initLeafletMap()
      })
    } catch (err) {
      this.loading = false
      this.firebaseError = err.message || 'Firebase initialize ล้มเหลว'
    }
  },
  beforeDestroy () {
    if (this.unsubscribe) this.unsubscribe()
    if (this._fbTimeout) clearTimeout(this._fbTimeout)
    if (this.leafletMap) {
      this.leafletMap.remove()
      this.leafletMap = null
    }
  },
  methods: {
    setTileProvider (provider) {
      this.mapProvider = provider
      this.$nextTick(() => {
        if (!this.leafletMap) {
          this.initLeafletMap()
        } else {
          this.leafletMap.invalidateSize()
          const url = TILE_URLS[provider] || TILE_URLS.google_roadmap
          if (this.leafletTileLayer) {
            this.leafletTileLayer.setUrl(url)
          }
        }
      })
    },
    initLeafletMap () {
      if (!this.L || this.leafletMap) return
      const el = document.getElementById('leaflet-tracking-map')
      if (!el) return

      // Default center: MFU Campus, Chiang Rai
      this.leafletMap = this.L.map('leaflet-tracking-map', {
        zoomControl: true,
        attributionControl: false
      }).setView([20.044, 99.894], 15)

      const tileUrl = TILE_URLS[this.mapProvider] || TILE_URLS.google_roadmap
      this.leafletTileLayer = this.L.tileLayer(tileUrl, {
        maxZoom: 20
      }).addTo(this.leafletMap)

      this.updateLeafletMarkers()
    },
    updateLeafletMarkers () {
      if (!this.leafletMap || !this.L) return

      const seenIds = new Set()
      this.filteredGuards.forEach(guard => {
        const lat = Number(guard.lat)
        const lng = Number(guard.lng)
        if (Number.isNaN(lat) || Number.isNaN(lng)) return
        const id = guard.id || guard.name
        seenIds.add(id)

        const isAlert = guard.status === 'out_of_scope'
        const color = isAlert ? '#E53935' : '#2E7D32'
        const iconHtml = `
          <div style="position:relative;display:flex;flex-direction:column;align-items:center;">
            <div style="width:34px;height:34px;border-radius:50%;background:${color};border:2.5px solid #fff;box-shadow:0 3px 8px rgba(0,0,0,.35);display:flex;align-items:center;justify-content:center;color:#fff;font-size:14px;font-weight:bold;">
              ${isAlert ? '⚠️' : '🛡️'}
            </div>
            <div style="background:#fff;border:1px solid #E9EBF0;padding:2px 8px;border-radius:8px;font-size:11px;font-weight:700;white-space:nowrap;margin-top:3px;box-shadow:0 2px 6px rgba(0,0,0,.15);color:#1B1B1F;">
              ${guard.name}${isAlert ? ' — นอกพื้นที่' : ''}
            </div>
          </div>
        `

        const customIcon = this.L.divIcon({
          className: 'leaflet-custom-pin',
          html: iconHtml,
          iconSize: [120, 60],
          iconAnchor: [60, 20]
        })

        if (this.leafletMarkers[id]) {
          this.leafletMarkers[id].setLatLng([lat, lng]).setIcon(customIcon)
        } else {
          const marker = this.L.marker([lat, lng], { icon: customIcon })
            .addTo(this.leafletMap)
            .on('click', () => {
              this.selectedGuard = guard
            })
          this.leafletMarkers[id] = marker
        }
      })

      // Remove stale markers
      Object.keys(this.leafletMarkers).forEach(id => {
        if (!seenIds.has(id)) {
          this.leafletMap.removeLayer(this.leafletMarkers[id])
          delete this.leafletMarkers[id]
        }
      })

      // Auto center if guards exist
      if (this.filteredGuards.length > 0) {
        const first = this.filteredGuards[0]
        const lat = Number(first.lat)
        const lng = Number(first.lng)
        if (!Number.isNaN(lat) && !Number.isNaN(lng) && !this.selectedGuard) {
          this.leafletMap.panTo([lat, lng])
        }
      }
    },
    flyToSelectedGuard () {
      if (!this.selectedGuard) return
      const lat = Number(this.selectedGuard.lat)
      const lng = Number(this.selectedGuard.lng)
      if (!Number.isNaN(lat) && !Number.isNaN(lng)) {
        if (this.leafletMap) {
          this.leafletMap.flyTo([lat, lng], 17, { duration: 1.2 })
        }
      }
    },
    toggleFullscreen () {
      const el = this.$refs.mapCard
      if (!document.fullscreenElement) {
        if (el && el.requestFullscreen) el.requestFullscreen()
      } else if (document.exitFullscreen) {
        document.exitFullscreen()
      }
    },
    async handleFbLogin () {
      if (!this.fbEmail || !this.fbPass) {
        this.loginError = 'กรุณากรอกอีเมลและรหัสผ่าน'
        return
      }
      this.loggingIn = true
      this.loginError = ''
      try {
        await loginFirebase(this.fbEmail, this.fbPass)
        this.loading = true
        this.firebaseError = ''
        if (this.unsubscribe) this.unsubscribe()
        this.unsubscribe = subscribeCollection(
          COLLECTIONS.GUARDS,
          rows => {
            this.guards = rows
            this.loading = false
            this.firebaseError = ''
            this.updateLeafletMarkers()
          },
          {
            onError: err => {
              this.loading = false
              this.firebaseError = (err && err.message) ? err.message : 'ไม่สามารถเชื่อมต่อ Firebase ได้'
            }
          }
        )
      } catch (err) {
        this.loginError = (err && err.message) ? err.message : 'เข้าสู่ระบบ Firebase ไม่สำเร็จ'
      } finally {
        this.loggingIn = false
      }
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";

.mode-switcher {
  display: flex;
  background: var(--surface);
  border: 1px solid var(--divider);
  border-radius: var(--r-md);
  padding: 3px;
  gap: 3px;
}
.mode-btn {
  border: none;
  background: transparent;
  padding: 6px 12px;
  border-radius: 10px;
  font-size: 12.5px;
  font-weight: 600;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all .2s;
  &:hover { color: var(--text-primary); }
  &.active {
    background: var(--primary-dark);
    color: #fff;
    box-shadow: 0 2px 6px rgba(0,0,0,.15);
  }
}

.leaflet-map-surface {
  position: absolute;
  inset: 0;
  z-index: 1;
  width: 100%;
  height: 100%;
  border-radius: var(--r-xl);
}

.fb-status {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;

  .fb-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
  }
}
.fb-connected { background: rgba(46,125,50,.1); color: #2E7D32; .fb-dot { background: #2E7D32; } }
.fb-connecting { background: rgba(212,175,55,.12); color: #b8960a; .fb-dot { background: #D4AF37; animation: blink 1s infinite; } }
.fb-error { background: rgba(229,57,53,.1); color: var(--accent-red); .fb-dot { background: var(--accent-red); } }

@keyframes blink { 0%,100%{opacity:1} 50%{opacity:.3} }

.stat-mini {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 13px;
  color: var(--text-secondary);
  background: #fff;
  border-radius: 8px;
  padding: 4px 10px;
  box-shadow: 0 1px 4px rgba(0,0,0,.06);
}
.dot-green { width:8px; height:8px; border-radius:50%; background:#2E7D32; display:inline-block; }
.dot-red   { width:8px; height:8px; border-radius:50%; background:var(--accent-red); display:inline-block; }

.map-loading {
  position: absolute;
  inset: 0;
  z-index: 10;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  background: rgba(245,247,251,.92);
  gap: 10px;
  p { margin: 0; font-size: 14px; color: var(--text-secondary); }
}
.map-error { background: rgba(245,247,251,.96); }

.map-empty-overlay {
  position: absolute;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 5;
  background: rgba(255,255,255,.95);
  border-radius: 14px;
  padding: 14px 20px;
  display: flex;
  align-items: center;
  gap: 12px;
  box-shadow: 0 4px 16px rgba(0,0,0,.12);
  p { margin: 0; text-align: left; }
}

.spinner {
  width: 36px;
  height: 36px;
  border: 3px solid var(--divider);
  border-top-color: var(--primary-red);
  border-radius: 50%;
  animation: spin .7s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
</style>
