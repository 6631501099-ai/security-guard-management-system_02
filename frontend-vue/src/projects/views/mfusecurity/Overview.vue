<template>
  <div class="mfu-security">
    <div class="row-top" style="align-items:flex-start;">
      <div style="flex:1;">
        <div class="page-title">แดชบอร์ดผู้ดูแลระบบ</div>
        <p class="body-text">ควบคุมภาพรวมเจ้าหน้าที่การ์ด สถานะการตรวจตรา และเหตุฉุกเฉินที่เข้ามาแบบเรียลไทม์ (ข้อมูลซิงก์กับ Firebase)</p>
      </div>
      <button
        class="icon-btn"
        style="background:var(--surface);box-shadow:var(--shadow-card);width:44px;height:44px;border-radius:50%;position:relative;flex-shrink:0;"
        title="การแจ้งเตือน"
        @click="$router.push('/mfu-security/sos')"
      >
        <CIcon name="cil-bell" />
        <span
          v-if="pendingSosCount"
          style="position:absolute;top:2px;right:2px;width:9px;height:9px;border-radius:50%;background:var(--accent-red);"
        ></span>
      </button>
    </div>

    <div v-if="loading" style="text-align:center;padding:40px;color:var(--text-secondary);">
      <div class="mfu-spinner"></div>
      <p style="margin-top:12px;">กำลังเชื่อมต่อกับ Firebase...</p>
    </div>
    <div v-else-if="firebaseError" class="alert alert-danger mfu-error">{{ firebaseError }}</div>
    <div v-else class="stat-wrap">
      <div class="stat-card">
        <div class="stat-icon" style="background:rgba(46,125,50,0.12)">
          <CIcon name="cil-people" style="color:#2E7D32" />
        </div>
        <div>
          <div class="stat-label">การ์ดออนไลน์</div>
          <div class="stat-value" style="color:var(--success)">{{ onlineCount }}</div>
          <div style="font-size:11px;color:var(--text-secondary);margin-top:2px;">(ทั้งหมดในระบบ {{ guards.length }} คน)</div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon" style="background:rgba(229,57,53,0.12)">
          <CIcon name="cil-warning" style="color:#E53935" />
        </div>
        <div>
          <div class="stat-label">นอกพื้นที่ปฏิบัติงาน</div>
          <div class="stat-value" style="color:var(--accent-red)">{{ outOfScopeCount }}</div>
        </div>
      </div>
      <div class="stat-card" style="min-width:260px;">
        <div class="stat-icon" style="background:rgba(212,175,55,0.16)">
          <CIcon name="cil-bell" style="color:#D4AF37" />
        </div>
        <div>
          <div class="stat-label">SOS รอดำเนินการ</div>
          <div class="stat-value" style="color:var(--warning)">{{ pendingSosCount }}</div>
          <div style="font-size:11px;color:var(--text-secondary);margin-top:2px;">(การแจ้งเหตุทั้งหมด {{ sosAlerts.length }} รายการ)</div>
        </div>
      </div>
    </div>

    <div class="card quick-card">
      <div class="section-title" style="margin:0;">ทางลัด</div>
      <div class="chip-wrap">
        <button class="quick-chip" @click="$router.push('/mfu-security/tracking')">
          <CIcon name="cil-location-pin" />เปิดหน้าติดตามพิกัด
        </button>
        <button class="quick-chip" @click="$router.push('/mfu-security/sos')">
          <CIcon name="cil-bell" />ตรวจสอบ SOS
        </button>
        <button class="quick-chip" @click="$router.push('/mfu-security/guards')">
          <CIcon name="cil-people" />รายชื่อการ์ด
        </button>
      </div>
    </div>

    <div class="card" style="margin-top:14px;padding:16px 18px;display:flex;gap:10px;align-items:flex-start;">
      <CIcon name="cil-lock-locked" style="color:var(--text-secondary);flex-shrink:0;margin-top:2px;" />
      <p class="body-text" style="margin:0;">
        ทุกหน้าอยู่หลังระบบล็อกอิน — ต้องมี role "admin" ใน Firestore ถึงเข้าดูข้อมูลจริงได้
      </p>
    </div>
  </div>
</template>

<script>
import { subscribeCollection, isGuardOnline, COLLECTIONS, SOS_ORDER_FIELD } from '@/service/firebase'

export default {
  name: 'MfuSecurityOverview',
  data () {
    return {
      guards: [],
      sosAlerts: [],
      unsubscribers: [],
      loading: true,
      firebaseError: ''
    }
  },
  computed: {
    // `locations` docs use `outOfScope: boolean` (not a `status` string) and admin only
    // counts a guard as "online" if they've checked in within the last 60 seconds — same
    // rule the Flutter admin dashboard uses, so the two admin surfaces always agree.
    onlineGuards () {
      return this.guards.filter(isGuardOnline)
    },
    onlineCount () {
      return this.onlineGuards.filter(g => g.outOfScope !== true).length
    },
    outOfScopeCount () {
      return this.onlineGuards.filter(g => g.outOfScope === true).length
    },
    pendingSosCount () {
      return this.sosAlerts.filter(s => s.status === 'pending').length
    }
  },
  mounted () {
    const handleErr = err => {
      this.loading = false
      this.firebaseError = (err && err.message) ? err.message : 'ไม่สามารถเชื่อมต่อ Firebase ได้'
    }
    this.unsubscribers.push(
      subscribeCollection(COLLECTIONS.GUARDS, rows => {
        this.guards = rows
        this.loading = false
      }, { onError: handleErr }),
      subscribeCollection(COLLECTIONS.SOS, rows => {
        this.sosAlerts = rows
        this.loading = false
      }, { orderByField: SOS_ORDER_FIELD, onError: handleErr })
    )
    this._fbTimeout = setTimeout(() => {
      if (this.loading) {
        this.loading = false
        this.firebaseError = 'ไม่ได้รับข้อมูลจาก Firebase ภายใน 8 วินาที'
      }
    }, 8000)
  },
  beforeDestroy () {
    this.unsubscribers.forEach(unsub => unsub && unsub())
    if (this._fbTimeout) clearTimeout(this._fbTimeout)
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
