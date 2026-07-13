<template>
  <div class="map-page">

    <!-- ============================================================
         SOS ALERT BANNER (latest pending)
    ============================================================ -->
    <div v-if="latestSos" class="sos-banner">
      <div class="sos-banner__left">
        <span class="sos-banner__icon">🚨</span>
        <div>
          <div class="sos-banner__title">SOS ALERT FROM {{ latestSos.name }}</div>
          <div class="sos-banner__detail">Email: {{ latestSos.email }}</div>
          <div class="sos-banner__detail">Message: {{ latestSos.message }}</div>
          <div class="sos-banner__detail">
            Lat: {{ latestSos.lat }} | Lng: {{ latestSos.lng }}
          </div>
          <div class="sos-banner__status">Status: {{ latestSos.status }}</div>
        </div>
      </div>
      <div class="sos-banner__actions">
        <button class="sos-btn sos-btn--dark" @click="flyToSos">📍 OPEN LOCATION</button>
        <button class="sos-btn sos-btn--green" @click="acceptSos(latestSos._id)">✔ ACCEPT</button>
      </div>
    </div>

    <!-- ============================================================
         HEADER ROW
    ============================================================ -->
    <div class="map-topbar">
      <div class="map-topbar__left">
        <div class="map-header__eyebrow">Security Guard Management System</div>
        <h1 class="map-title">Live Map Tracking</h1>
      </div>

      <!-- Live Tracking Toggle -->
      <button
        class="track-btn"
        :class="isTracking ? 'track-btn--active' : ''"
        @click="toggleTracking"
      >
        <span class="track-btn__dot" :class="isTracking ? 'track-btn__dot--live' : ''"></span>
        {{ isTracking ? '🔴 LIVE Tracking ON' : '📍 Start Tracking' }}
      </button>

      <!-- Online Badge -->
      <div class="online-badge">
        <span class="online-badge__dot"></span>
        <span class="online-badge__count">{{ onlineGuards.length }}</span>
        <span class="online-badge__label">Guards Online</span>
      </div>

      <!-- Search -->
      <div class="search-box">
        <span class="search-box__icon">🔍</span>
        <input
          v-model="search"
          class="search-box__input"
          type="text"
          placeholder="Search guard email..."
        />
      </div>
    </div>

    <!-- Tracking Status Bar -->
    <div v-if="trackingStatus" class="tracking-bar" :class="trackingBarClass">
      {{ trackingStatus }}
    </div>

    <!-- ============================================================
         MAP + TABLE
    ============================================================ -->
    <div class="map-layout">

      <!-- MAP -->
      <div class="map-panel">
        <div id="leaflet-map" class="leaflet-container"></div>

        <!-- My Location Marker Info -->
        <div v-if="myPosition" class="my-location-info">
          📍 My Location: {{ formatCoord(myPosition.lat) }}, {{ formatCoord(myPosition.lng) }}
        </div>

        <!-- Legend -->
        <div class="map-legend">
          <div class="map-legend__item">
            <span class="map-legend__dot map-legend__dot--me"></span> You (Admin)
          </div>
          <div class="map-legend__item">
            <span class="map-legend__dot map-legend__dot--online"></span> Online (&lt;15s)
          </div>
          <div class="map-legend__item">
            <span class="map-legend__dot map-legend__dot--idle"></span> Idle (15–60s)
          </div>
        </div>
      </div>

      <!-- ONLINE GUARDS TABLE -->
      <div class="guard-panel">
        <div class="guard-panel__header">
          <span>🛡 Online Guards</span>
          <span class="guard-panel__count">{{ filteredGuards.length }}</span>
        </div>

        <div v-if="filteredGuards.length === 0" class="guard-panel__empty">
          No guards online
        </div>

        <div
          v-for="guard in filteredGuards"
          :key="guard._id || guard.email"
          class="guard-card"
          @click="flyToGuard(guard)"
        >
          <div
            class="guard-card__avatar"
            :class="guard.diff <= 15 ? 'guard-card__avatar--green' : 'guard-card__avatar--orange'"
          >🛡</div>
          <div class="guard-card__info">
            <div class="guard-card__name">{{ guard.name }}</div>
            <div class="guard-card__email">{{ guard.email }}</div>
            <div class="guard-card__coords">Lat: {{ formatCoord(guard.lat) }} Lng: {{ formatCoord(guard.lng) }}</div>
            <div class="guard-card__updated">Updated {{ guard.diff }}s ago</div>
          </div>
          <span
            class="guard-card__badge"
            :class="guard.diff <= 15 ? 'guard-card__badge--green' : 'guard-card__badge--orange'"
          >ONLINE</span>
        </div>
      </div>

    </div>
  </div>
</template>

<script>
import firebase from 'firebase/app'
import 'firebase/firestore'
import Service from '@/service/api'

let L = null
let myMarker = null

const PROJECT_END_FIREBASE_CONFIG = {
  apiKey: 'AIzaSyCJCeOSI7_K6yasAhWXQ2ZKMz5Jq2H5WtM',
  authDomain: 'location-app-project-ce854.firebaseapp.com',
  databaseURL: 'https://location-app-project-ce854-default-rtdb.asia-southeast1.firebasedatabase.app',
  projectId: 'location-app-project-ce854',
  storageBucket: 'location-app-project-ce854.firebasestorage.app',
  messagingSenderId: '755991867844',
  appId: '1:755991867844:web:24089d90989379b7b63491',
  measurementId: 'G-LR2V8EJWN3'
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

const MOCK_SOS = []

export default {
  name: 'MapView',

  data () {
    return {
      search: '',
      locations: [],
      accountLocations: [],
      projectEndLocations: [],
      sosList: [],
      map: null,
      markers: {},
      pollTimer: null,
      projectEndUnsubscribe: null,
      projectEndStatus: 'กำลังเชื่อมต่อตำแหน่งมือถือ...',
      projectEndDocCount: 0,
      // Live Tracking
      isTracking: false,
      watchId: null,
      myPosition: null,
      trackingStatus: '',
    }
  },

  computed: {
    onlineGuards () {
      const now = Date.now()
      return this.locations.filter(loc => {
        const diff = Math.floor((now - loc.lastUpdate) / 1000)
        return diff <= 60
      })
    },
    filteredGuards () {
      const now = Date.now()
      const q = this.search.toLowerCase()
      return this.onlineGuards
        .filter(g => (g.email || '').toLowerCase().includes(q))
        .map(g => ({ ...g, diff: Math.floor((now - g.lastUpdate) / 1000) }))
    },
    latestSos () {
      return this.sosList.find(s => s.status === 'pending') || null
    },
    trackingBarClass () {
      if (!this.trackingStatus) return ''
      if (this.trackingStatus.includes('error') || this.trackingStatus.includes('ไม่')) return 'tracking-bar--error'
      if (this.isTracking) return 'tracking-bar--live'
      return 'tracking-bar--info'
    }
  },

  async mounted () {
      await this.fetchLocations()
      await this.fetchSos()
      this.listenToProjectEndLocations()
      L = await loadLeaflet()
      this.$nextTick(() => { this.initMap() })
      this.pollTimer = setInterval(async () => {
        await this.fetchLocations()
        await this.fetchSos()
        this.refreshMarkers()
      }, 5000)
    },
  beforeDestroy () {
    if (this.projectEndUnsubscribe) {
      this.projectEndUnsubscribe()
      this.projectEndUnsubscribe = null
    }
    if (this.pollTimer) clearInterval(this.pollTimer)
    this.stopTracking()
    if (this.map) this.map.remove()
  },

  methods: {
    // ── Data ──────────────────────────────────────────────────────
    async fetchLocations () {
      try {
        const response = await Service.accounts('list')
        const rawAccounts = response && response.data && response.data.data ? response.data.data : []
        this.accountLocations = (rawAccounts || []).map(account => this.normalizeAccountLocation(account)).filter(Boolean)
        this.locations = this.mergeLocations(this.accountLocations, this.projectEndLocations)
      } catch (e) {
        console.warn('Fetch locations failed', e)
        this.accountLocations = []
        this.locations = this.mergeLocations([], this.projectEndLocations)
        this.trackingStatus = '⚠️ ไม่สามารถโหลดตำแหน่งจากระบบได้'
      }
    },
    normalizeAccountLocation (account) {
      const gps = account && account.address && Array.isArray(account.address)
        ? (account.address[0] && account.address[0].gps) || null
        : null
      const latitude = gps && typeof gps.latitude === 'number' ? gps.latitude : null
      const longitude = gps && typeof gps.longitude === 'number' ? gps.longitude : null

      if (latitude === null || longitude === null) return null

      const updatedAt = account && (account.updatedAt || account.createdAt)
        ? new Date(account.updatedAt || account.createdAt).getTime()
        : Date.now()

      return {
        _id: account && (account._id || account.id) ? String(account._id || account.id) : String((account && account.email) || 'location'),
        name: account && (account.name || account.fullName || account.firstName || account.email)
          ? (account.name || account.fullName || account.firstName || account.email)
          : 'Unknown guard',
        email: account && account.email ? account.email : '',
        lat: latitude,
        lng: longitude,
        lastUpdate: Number.isFinite(updatedAt) ? updatedAt : Date.now()
      }
    },
    normalizeProjectEndLocation (documentSnapshot) {
      const data = documentSnapshot && typeof documentSnapshot.data === 'function'
        ? documentSnapshot.data()
        : documentSnapshot && typeof documentSnapshot === 'object'
          ? documentSnapshot
          : null

      if (!data) return null

      const latitude = this.coerceCoordinate(data.lat ?? data.latitude)
      const longitude = this.coerceCoordinate(data.lng ?? data.longitude ?? data.lon)
      if (latitude === null || longitude === null) return null

      const timestamp = data.lastUpdate
      let lastUpdate = Date.now()
      if (timestamp && typeof timestamp.toDate === 'function') {
        lastUpdate = timestamp.toDate().getTime()
      } else if (timestamp && typeof timestamp === 'object' && typeof timestamp.seconds === 'number') {
        lastUpdate = new Date(timestamp.seconds * 1000).getTime()
      } else if (data.updatedAt) {
        lastUpdate = new Date(data.updatedAt).getTime()
      }

      if (!Number.isFinite(lastUpdate) || lastUpdate <= 0) {
        lastUpdate = Date.now()
      }

      return {
        _id: documentSnapshot && documentSnapshot.id ? String(documentSnapshot.id) : String(data._id || data.id || data.email || 'project-end-location'),
        name: data.name || data.fullName || data.email || 'Mobile Guard',
        email: data.email || '',
        lat: latitude,
        lng: longitude,
        lastUpdate,
        source: 'project-end'
      }
    },
    coerceCoordinate (value) {
      if (typeof value === 'number' && Number.isFinite(value)) return value
      if (typeof value === 'string' && value.trim() !== '') {
        const parsed = Number(value)
        return Number.isFinite(parsed) ? parsed : null
      }
      return null
    },
    mergeLocations (accountLocations, projectEndLocations) {
      const merged = []
      const seen = new Set()
      const appendLocation = (location) => {
        if (!location) return
        const key = `${location._id || ''}:${location.email || ''}`
        if (seen.has(key)) return
        seen.add(key)
        merged.push(location)
      }

      ;(accountLocations || []).forEach(appendLocation)
      ;(projectEndLocations || []).forEach(appendLocation)
      return merged
    },
    listenToProjectEndLocations () {
      if (this.projectEndUnsubscribe) return
      if (!firebase.apps.length) {
        firebase.initializeApp(PROJECT_END_FIREBASE_CONFIG)
      }

      try {
        const db = firebase.firestore()
        this.projectEndUnsubscribe = db.collection('locations').onSnapshot((snapshot) => {
          const docs = (snapshot.docs || [])
          this.projectEndDocCount = docs.length
          this.projectEndStatus = `ตำแหน่งมือถือ ${docs.length} รายการ`;
          console.debug('ProjectEND location stream', docs.length, docs.map(doc => doc.id))

          this.projectEndLocations = docs
            .map(doc => this.normalizeProjectEndLocation(doc))
            .filter(Boolean)
          this.locations = this.mergeLocations(this.accountLocations, this.projectEndLocations)
          this.refreshMarkers()
        }, (error) => {
          console.warn('ProjectEND location stream failed', error)
          this.projectEndStatus = 'ไม่สามารถเชื่อมต่อตำแหน่งมือถือได้'
        })
      } catch (error) {
        console.warn('ProjectEND Firestore is unavailable', error)
        this.projectEndStatus = 'Firebase ไม่พร้อมใช้งาน'
      }
    },
    async sendMyLocation (coords) {
      if (!coords || typeof coords.latitude !== 'number' || typeof coords.longitude !== 'number') {
        return;
      }
      try {
        await Service.authenticated('update-location', {
          gps: {
            latitude: coords.latitude,
            longitude: coords.longitude
          }
        });
      } catch (err) {
        console.warn('Send location update failed', err);
        if (this.isTracking) {
          this.trackingStatus = '⚠️ ส่งตำแหน่งไม่สำเร็จ กรุณาลองใหม่';
        }
      }
    },
    async fetchSos () {
      try {
        // TODO: const res = await this.$http.get('/api/sos?status=pending')
        // this.sosList = res.data
        this.sosList = MOCK_SOS
      } catch (e) {
        this.sosList = MOCK_SOS
      }
    },
    async acceptSos (id) {
      try {
        // TODO: await this.$http.put(`/api/sos/${id}`, { status: 'accepted' })
        const sos = this.sosList.find(s => s._id === id)
        if (sos) sos.status = 'accepted'
      } catch (e) {
        console.error('Accept SOS failed', e)
      }
    },

    // ── Map ───────────────────────────────────────────────────────
    initMap () {
      if (!L || this.map) return
      this.map = L.map('leaflet-map').setView([20.044, 99.894], 14)
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 19
      }).addTo(this.map)
      this.refreshMarkers()
    },

    refreshMarkers () {
      if (!this.map || !L) return
      const now = Date.now()
      Object.keys(this.markers).forEach(id => {
        const loc = this.locations.find(l => l._id === id)
        if (!loc) { this.map.removeLayer(this.markers[id]); delete this.markers[id] }
      })
      this.locations.forEach(loc => {
        const lastUpdate = Number.isFinite(loc.lastUpdate) ? loc.lastUpdate : now
        const diff = Math.floor((now - lastUpdate) / 1000)
        if (diff > 120) return
        const email = (loc.email || '').toLowerCase()
        if (!email.includes(this.search.toLowerCase())) return
        const color = diff <= 15 ? '#22c55e' : '#f97316'
        const icon = L.divIcon({
          className: '',
          html: `<div style="width:34px;height:34px;border-radius:50%;background:${color};border:3px solid white;box-shadow:0 2px 8px rgba(0,0,0,.35);display:flex;align-items:center;justify-content:center;font-size:15px;cursor:pointer;">🛡</div>`,
          iconSize: [34, 34],
          iconAnchor: [17, 17]
        })
        if (this.markers[loc._id]) {
          this.markers[loc._id].setLatLng([loc.lat, loc.lng]).setIcon(icon)
        } else {
          this.markers[loc._id] = L.marker([loc.lat, loc.lng], { icon })
            .addTo(this.map)
            .bindPopup(`<b>${loc.name}</b><br>${loc.email}<br><span style="color:#22c55e;font-weight:bold;">ONLINE</span>`)
        }
      })
    },

    flyToGuard (guard) {
      if (this.map) {
        this.map.flyTo([guard.lat, guard.lng], 17)
        const marker = this.markers[guard._id]
        if (marker) marker.openPopup()
      }
    },
    flyToSos () {
      if (this.latestSos && this.map) {
        this.map.flyTo([this.latestSos.lat, this.latestSos.lng], 18)
      }
    },

    // ── LIVE TRACKING ─────────────────────────────────────────────
    toggleTracking () {
      if (this.isTracking) {
        this.stopTracking()
      } else {
        this.startTracking()
      }
    },

    startTracking () {
      if (!navigator.geolocation) {
        this.trackingStatus = '❌ Browser ไม่รองรับ Geolocation'
        return
      }
      this.trackingStatus = '📡 กำลังขอสิทธิ์เข้าถึงตำแหน่ง...'
      this.isTracking = true

      this.watchId = navigator.geolocation.watchPosition(
        (position) => {
          const { latitude, longitude, accuracy } = position.coords
          this.myPosition = { lat: latitude, lng: longitude }
          this.trackingStatus = `🟢 LIVE — Accuracy: ±${Math.round(accuracy)}m`

          if (this.map && L) {
            // Update or create "My Location" marker
            if (myMarker) {
              myMarker.setLatLng([latitude, longitude])
            } else {
              const meIcon = L.divIcon({
                className: '',
                html: `<div style="width:20px;height:20px;border-radius:50%;background:#3b82f6;border:3px solid white;box-shadow:0 0 0 6px rgba(59,130,246,.3);"></div>`,
                iconSize: [20, 20],
                iconAnchor: [10, 10]
              })
              myMarker = L.marker([latitude, longitude], { icon: meIcon, zIndexOffset: 1000 })
                .addTo(this.map)
                .bindPopup('<b>📍 คุณอยู่ที่นี่</b>')
            }

            // Smooth pan to my location
            this.map.panTo([latitude, longitude])

            // Send location update to backend
            this.sendMyLocation({ latitude, longitude })
          }
        },
        (error) => {
          const msgs = {
            1: 'ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง (Permission denied)',
            2: 'ไม่สามารถระบุตำแหน่งได้ (Position unavailable)',
            3: 'หมดเวลา (Timeout)'
          }
          this.trackingStatus = `❌ ${msgs[error.code] || error.message}`
          this.isTracking = false
        },
        {
          enableHighAccuracy: true,
          maximumAge: 0,
          timeout: 15000
        }
      )
    },

    stopTracking () {
      if (this.watchId !== null) {
        navigator.geolocation.clearWatch(this.watchId)
        this.watchId = null
      }
      this.isTracking = false
      this.trackingStatus = '⏹ หยุดติดตามตำแหน่งแล้ว'
      if (myMarker && this.map) {
        this.map.removeLayer(myMarker)
        myMarker = null
      }
      this.myPosition = null
      setTimeout(() => { this.trackingStatus = '' }, 3000)
    },

    formatCoord (val) {
      return typeof val === 'number' ? val.toFixed(5) : val
    }
  }
}
</script>

<style scoped>
.map-page {
  padding: 1.25rem 1.5rem;
  background: #f5f7fb;
  min-height: 100vh;
  font-family: 'Inter', 'Helvetica Neue', sans-serif;
}

/* SOS Banner */
.sos-banner {
  background: linear-gradient(135deg, #dc2626, #991b1b);
  border-radius: 16px;
  padding: 1.25rem 1.5rem;
  margin-bottom: 1.25rem;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  box-shadow: 0 4px 24px rgba(220,38,38,.35);
  animation: sos-pulse 1.5s ease-in-out infinite alternate;
}
@keyframes sos-pulse {
  from { box-shadow: 0 4px 24px rgba(220,38,38,.35); }
  to   { box-shadow: 0 4px 40px rgba(220,38,38,.7); }
}
.sos-banner__left   { display: flex; gap: 1rem; align-items: flex-start; flex: 1; }
.sos-banner__icon   { font-size: 2rem; flex-shrink: 0; }
.sos-banner__title  { font-size: 1.2rem; font-weight: 700; color: #fff; margin-bottom: .25rem; }
.sos-banner__detail { color: rgba(255,255,255,.85); font-size: .9rem; }
.sos-banner__status { color: #fff; font-weight: 700; margin-top: .35rem; }
.sos-banner__actions { display: flex; flex-direction: column; gap: .5rem; flex-shrink: 0; }
.sos-btn { padding: .55rem 1.2rem; border: none; border-radius: 10px; font-weight: 600; cursor: pointer; font-size: .9rem; transition: opacity .2s; }
.sos-btn:hover { opacity: .85; }
.sos-btn--dark  { background: #1f1c18; color: #fff; }
.sos-btn--green { background: #16a34a; color: #fff; }

/* Top Bar */
.map-topbar {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}
.map-topbar__left { flex: 1; min-width: 160px; }
.map-header__eyebrow {
  font-size: .7rem;
  font-weight: 700;
  letter-spacing: .08em;
  text-transform: uppercase;
  color: #8c1515;
  margin-bottom: .1rem;
}
.map-title { font-size: 1.5rem; font-weight: 700; margin: 0; color: #1a1a2e; }

/* Tracking button */
.track-btn {
  display: flex;
  align-items: center;
  gap: .5rem;
  padding: .5rem 1.1rem;
  border: 2px solid #e5e7eb;
  border-radius: 30px;
  background: #fff;
  font-weight: 600;
  font-size: .9rem;
  cursor: pointer;
  transition: all .25s;
}
.track-btn:hover { border-color: #3b82f6; color: #3b82f6; }
.track-btn--active { background: #3b82f6; color: #fff; border-color: #3b82f6; }
.track-btn__dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #9ca3af;
  flex-shrink: 0;
}
.track-btn__dot--live {
  background: #fff;
  animation: blink 0.8s infinite alternate;
}

/* Tracking Status Bar */
.tracking-bar {
  padding: .45rem 1rem;
  border-radius: 10px;
  font-size: .88rem;
  font-weight: 500;
  margin-bottom: .75rem;
}
.tracking-bar--live  { background: #dcfce7; color: #15803d; }
.tracking-bar--error { background: #fee2e2; color: #b91c1c; }
.tracking-bar--info  { background: #e0f2fe; color: #0369a1; }

/* Online badge */
.online-badge {
  display: flex;
  align-items: center;
  gap: .5rem;
  background: #16a34a;
  color: #fff;
  padding: .45rem 1rem;
  border-radius: 30px;
  font-weight: 700;
  font-size: .9rem;
  box-shadow: 0 2px 10px rgba(22,163,74,.3);
}
.online-badge__dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: #fff;
  animation: blink 1s infinite alternate;
}
@keyframes blink { from { opacity: 1; } to { opacity: .2; } }

/* Search */
.search-box {
  display: flex;
  align-items: center;
  gap: .5rem;
  background: #fff;
  border-radius: 14px;
  padding: .45rem 1rem;
  box-shadow: 0 2px 8px rgba(0,0,0,.07);
  min-width: 200px;
}
.search-box__icon  { font-size: 1rem; }
.search-box__input { border: none; outline: none; font-size: .9rem; background: transparent; width: 100%; }

/* Layout */
.map-layout {
  display: grid;
  grid-template-columns: 2fr 1fr;
  gap: 1.25rem;
  height: calc(100vh - 260px);
  min-height: 460px;
}

/* Map Panel */
.map-panel {
  position: relative;
  border-radius: 20px;
  overflow: hidden;
  background: #fff;
  box-shadow: 0 4px 20px rgba(0,0,0,.1);
}
.leaflet-container {
  width: 100%;
  height: 100%;
  min-height: 420px;
}
.my-location-info {
  position: absolute;
  top: 12px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 1000;
  background: rgba(255,255,255,.9);
  border-radius: 20px;
  padding: .35rem .9rem;
  font-size: .78rem;
  font-weight: 600;
  color: #1d4ed8;
  box-shadow: 0 2px 8px rgba(0,0,0,.15);
  white-space: nowrap;
}
.map-legend {
  position: absolute;
  bottom: 16px;
  left: 16px;
  z-index: 1000;
  background: rgba(255,255,255,.92);
  border-radius: 10px;
  padding: .5rem .75rem;
  font-size: .78rem;
  box-shadow: 0 2px 8px rgba(0,0,0,.15);
}
.map-legend__item { display: flex; align-items: center; gap: .4rem; margin: .15rem 0; }
.map-legend__dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
}
.map-legend__dot--me     { background: #3b82f6; box-shadow: 0 0 0 4px rgba(59,130,246,.25); }
.map-legend__dot--online { background: #22c55e; }
.map-legend__dot--idle   { background: #f97316; }

/* Guard Panel */
.guard-panel {
  background: #fff;
  border-radius: 20px;
  padding: 1rem;
  box-shadow: 0 4px 20px rgba(0,0,0,.1);
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: .75rem;
}
.guard-panel__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 1.05rem;
  font-weight: 700;
  color: #1a1a2e;
  padding-bottom: .5rem;
  border-bottom: 2px solid #f0f0f0;
}
.guard-panel__count {
  background: #e0f2fe;
  color: #0284c7;
  border-radius: 20px;
  padding: .1rem .6rem;
  font-size: .82rem;
}
.guard-panel__empty {
  text-align: center;
  color: #adb5bd;
  padding: 2rem 0;
  font-size: .92rem;
}

/* Guard Card */
.guard-card {
  display: flex;
  align-items: flex-start;
  gap: .75rem;
  padding: .75rem;
  border-radius: 14px;
  background: #f8fafc;
  cursor: pointer;
  transition: all .2s;
  border: 1px solid transparent;
}
.guard-card:hover {
  background: #eff6ff;
  border-color: #bfdbfe;
  box-shadow: 0 2px 8px rgba(59,130,246,.1);
}
.guard-card__avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.1rem;
  flex-shrink: 0;
}
.guard-card__avatar--green  { background: #dcfce7; }
.guard-card__avatar--orange { background: #ffedd5; }
.guard-card__info { flex: 1; min-width: 0; }
.guard-card__name    { font-weight: 600; color: #1a1a2e; font-size: .9rem; }
.guard-card__email   { color: #6b7280; font-size: .78rem; overflow: hidden; white-space: nowrap; text-overflow: ellipsis; }
.guard-card__coords  { color: #9ca3af; font-size: .75rem; margin-top: .2rem; }
.guard-card__updated { color: #16a34a; font-size: .75rem; font-weight: 600; }
.guard-card__badge {
  flex-shrink: 0;
  padding: .2rem .6rem;
  border-radius: 20px;
  font-size: .7rem;
  font-weight: 700;
  color: #fff;
  align-self: center;
}
.guard-card__badge--green  { background: #16a34a; }
.guard-card__badge--orange { background: #ea580c; }
</style>
