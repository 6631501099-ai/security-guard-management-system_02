<template>
  <div class="mfu-security">
    <div class="page-title">แดชบอร์ดผู้ดูแลระบบ</div>
    <p class="body-text">ควบคุมภาพรวมเจ้าหน้าที่การ์ด สถานะการตรวจตรา และเหตุฉุกเฉินที่เข้ามาแบบเรียลไทม์ (ข้อมูลซิงก์กับ Firebase)</p>

    <div class="stat-wrap">
      <div class="stat-card">
        <div class="stat-icon" style="background:rgba(46,125,50,0.12)">
          <CIcon name="cil-people" style="color:#2E7D32" />
        </div>
        <div>
          <div class="stat-label">การ์ดออนไลน์</div>
          <div class="stat-value" style="color:var(--success)">{{ onlineCount }}</div>
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
  </div>
</template>

<script>
import { subscribeCollection, COLLECTIONS } from '@/service/firebase'

export default {
  name: 'MfuSecurityOverview',
  data () {
    return {
      guards: [],
      sosAlerts: [],
      unsubscribers: []
    }
  },
  computed: {
    onlineCount () {
      return this.guards.filter(g => g.status !== 'out_of_scope').length
    },
    outOfScopeCount () {
      return this.guards.filter(g => g.status === 'out_of_scope').length
    },
    pendingSosCount () {
      return this.sosAlerts.filter(s => s.status === 'pending').length
    }
  },
  mounted () {
    this.unsubscribers.push(
      subscribeCollection(COLLECTIONS.GUARDS, rows => { this.guards = rows }),
      subscribeCollection(COLLECTIONS.SOS, rows => { this.sosAlerts = rows }, { orderByField: 'createdAt' })
    )
  },
  beforeDestroy () {
    this.unsubscribers.forEach(unsub => unsub && unsub())
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
