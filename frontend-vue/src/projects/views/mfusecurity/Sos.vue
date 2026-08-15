<template>
  <div class="mfu-security">
    <div class="section-title">แจ้งเตือนฉุกเฉิน SOS</div>

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
import { subscribeCollection, updateDocument, COLLECTIONS } from '@/service/firebase'

export default {
  name: 'MfuSecuritySos',
  data () {
    return {
      alerts: [],
      unsubscribe: null,
      filter: 'pending',
      selected: null,
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
    this.unsubscribe = subscribeCollection(COLLECTIONS.SOS, rows => { this.alerts = rows }, { orderByField: 'createdAt' })
  },
  beforeDestroy () {
    if (this.unsubscribe) this.unsubscribe()
  },
  methods: {
    openDetail (alert) {
      this.selected = alert
    },
    async acceptAlert (alert) {
      this.errorMessage = ''
      try {
        await updateDocument(COLLECTIONS.SOS, alert.id, { status: 'accepted' })
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
