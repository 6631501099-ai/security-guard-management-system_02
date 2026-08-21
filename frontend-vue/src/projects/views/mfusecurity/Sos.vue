<template>
  <div class="mfu-security">
    <div class="section-title">แจ้งเตือนฉุกเฉิน SOS</div>

    <div v-if="loading" style="text-align:center;padding:40px;color:var(--text-secondary);">
      <div class="mfu-spinner"></div>
      <p style="margin-top:12px;">กำลังโหลดข้อมูล SOS จาก Firebase...</p>
    </div>
    <div v-else-if="firebaseError" class="alert alert-danger mfu-error">{{ firebaseError }}</div>
    <template v-else>
    <div v-if="errorMessage" class="alert alert-danger mfu-error">{{ errorMessage }}</div>

    <div class="chips">
      <div class="fchip" :class="{ on: filter === 'pending' }" @click="filter = 'pending'">รอดำเนินการ</div>
      <div class="fchip" :class="{ on: filter === 'accepted' }" @click="filter = 'accepted'">ยอมรับแล้ว</div>
      <div class="fchip" :class="{ on: filter === 'all' }" @click="filter = 'all'">ทั้งหมด</div>
    </div>

    <div class="list">
      <div v-if="!filteredAlerts.length" class="mfu-empty">ไม่มีรายการแจ้งเหตุ</div>
      <div class="item-card" v-for="alert in filteredAlerts" :key="alert.id">
        <div class="item-row">
          <CIcon name="cil-warning" style="color:var(--accent-red)" />
          <p class="item-title" style="flex:1;">{{ alert.guardName }}</p>
          <span
            class="pill"
            :style="alert.status === 'accepted'
              ? 'background:rgba(46,125,50,.12);color:var(--success)'
              : 'background:rgba(229,57,53,.12);color:var(--accent-red)'"
          >{{ alert.status }}</span>
        </div>
        <p class="body-text" style="margin-top:8px;">{{ alert.message }}</p>
        <div class="sheet-actions" style="margin-top:12px;">
          <button class="action-btn" style="background:var(--primary-dark)" @click="openDetail(alert)">
            <CIcon name="cil-zoom" />ตรวจสอบ
          </button>
          <button class="action-btn" style="background:var(--info)" @click="$router.push('/mfu-security/tracking')">
            <CIcon name="cil-location-pin" />ระบุพิกัด
          </button>
          <button
            class="action-btn"
            style="background:var(--success)"
            :disabled="alert.status === 'accepted'"
            @click="acceptAlert(alert)"
          >
            <CIcon name="cil-check" />ยอมรับ
          </button>
        </div>
      </div>
    </div>
    </template>

    <div class="overlay" :class="{ show: !!selected }" @click.self="selected = null">
      <div class="sheet" v-if="selected">
        <div class="sheet-handle"></div>
        <div class="sheet-title-row">
          <CIcon name="cil-warning" />
          <h3>รายละเอียดแจ้งเหตุฉุกเฉิน</h3>
        </div>
        <div class="drow"><div class="k">ชื่อ</div><div class="v">{{ selected.guardName }}</div></div>
        <div class="drow"><div class="k">อีเมล</div><div class="v">{{ selected.guardEmail || '-' }}</div></div>
        <div class="drow"><div class="k">ตำแหน่ง</div><div class="v">{{ selected.lat }}, {{ selected.lng }}</div></div>
        <div class="drow"><div class="k">สถานะ</div><div class="v" style="color:var(--accent-red)">{{ selected.status }}</div></div>
        <div class="drow"><div class="k">ข้อความ</div><div class="v">{{ selected.message }}</div></div>
        <div class="sheet-actions">
          <button class="action-btn" style="background:var(--primary-dark)" @click="$router.push('/mfu-security/tracking')">
            <CIcon name="cil-map" />แผนที่
          </button>
          <button class="action-btn" style="background:var(--info)">
            <CIcon name="cil-phone" />โทรออก
          </button>
          <button
            class="action-btn"
            style="background:var(--success)"
            :disabled="selected.status === 'accepted'"
            @click="acceptAlert(selected)"
          >
            <CIcon name="cil-check" />ยอมรับ
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { subscribeCollection, updateDocument, notifyGuard, COLLECTIONS, SOS_ORDER_FIELD } from '@/service/firebase'

// `sos` docs are written by the Flutter guard app with `name`/`email` (not
// `guardName`/`guardEmail`) — alias them here so the template (and the rest of this
// component) can keep using the friendlier names without touching every line below.
function mapAlert (row) {
  return Object.assign({}, row, {
    guardName: row.name || 'ไม่ทราบชื่อ',
    guardEmail: row.email || ''
  })
}

export default {
  name: 'MfuSecuritySos',
  data () {
    return {
      alerts: [],
      unsubscribe: null,
      filter: 'pending',
      selected: null,
      loading: true,
      firebaseError: '',
      errorMessage: ''
    }
  },
  computed: {
    filteredAlerts () {
      if (this.filter === 'all') return this.alerts
      return this.alerts.filter(a => a.status === this.filter)
    }
  },
  mounted () {
    this.unsubscribe = subscribeCollection(COLLECTIONS.SOS, rows => {
      this.alerts = rows.map(mapAlert)
      this.loading = false
    }, {
      orderByField: SOS_ORDER_FIELD,
      onError: err => {
        this.loading = false
        this.firebaseError = (err && err.message) ? err.message : 'ไม่สามารถเชื่อมต่อ Firebase ได้'
      }
    })
    this._fbTimeout = setTimeout(() => {
      if (this.loading) {
        this.loading = false
        this.firebaseError = 'ไม่ได้รับข้อมูลจาก Firebase ภายใน 8 วินาที'
      }
    }, 8000)
  },
  beforeDestroy () {
    if (this.unsubscribe) this.unsubscribe()
    if (this._fbTimeout) clearTimeout(this._fbTimeout)
  },
  methods: {
    openDetail (alert) {
      this.selected = alert
    },
    async acceptAlert (alert) {
      this.errorMessage = ''
      try {
        await updateDocument(COLLECTIONS.SOS, alert.id, { status: 'accepted' })
        // `alert.uid` is the guard's Firebase Auth uid — sent by the guard app's
        // sendSOS() alongside name/email/lat/lng. Notifying them here mirrors
        // GuardActions.acceptSos on the Flutter admin side, so accepting from
        // EITHER admin surface correctly shows up on the guard's own Alerts screen.
        await notifyGuard(alert.uid, {
          title: 'SOS ได้รับการตอบรับแล้ว',
          subtitle: 'แอดมินรับทราบการแจ้งเหตุฉุกเฉินของคุณแล้ว กำลังส่งความช่วยเหลือ',
          category: 'emergency',
          relatedId: alert.id
        })
        if (this.selected && this.selected.id === alert.id) {
          this.selected = Object.assign({}, this.selected, { status: 'accepted' })
        }
      } catch (error) {
        this.errorMessage = 'ไม่สามารถอัปเดตสถานะได้ กรุณาลองใหม่'
      }
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
