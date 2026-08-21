<template>
  <div class="mfu-security">
    <div class="section-title">บันทึกล่าสุด</div>
    <p class="body-text" style="margin-bottom:14px;">เหตุการณ์ตรวจตรา กิจกรรม SOS และสถานะการ์ดล่าสุดทั้งหมด (เรียลไทม์)</p>

    <div v-if="loading" style="text-align:center;padding:40px;color:var(--text-secondary);">
      <div class="mfu-spinner"></div>
      <p style="margin-top:12px;">กำลังโหลดบันทึกจาก Firebase...</p>
    </div>
    <div v-else-if="firebaseError" class="alert alert-danger mfu-error">{{ firebaseError }}</div>
    <template v-else>
    <div class="search-field" style="margin-bottom:12px;">
      <CIcon name="cil-search" />
      <input v-model.trim="search" placeholder="ค้นหาชื่อเจ้าหน้าที่" />
    </div>
    <div class="chips">
      <div class="fchip" :class="{ on: filter === 'all' }" @click="filter = 'all'">ทั้งหมด</div>
      <div class="fchip" :class="{ on: filter === 'pending' }" @click="filter = 'pending'">รอดำเนินการ</div>
      <div class="fchip" :class="{ on: filter === 'accepted' }" @click="filter = 'accepted'">ยอมรับแล้ว</div>
    </div>

    <div class="list">
      <div v-if="!filteredLogs.length" class="mfu-empty">ไม่มีบันทึก</div>
      <div class="item-card" v-for="log in filteredLogs" :key="log.id">
        <div class="item-row">
          <CIcon
            :name="log.status === 'accepted' ? 'cil-check' : 'cil-warning'"
            :style="{ color: log.status === 'accepted' ? 'var(--success)' : 'var(--accent-red)' }"
          />
          <div>
            <p class="item-title">{{ log.guardName }}</p>
            <p class="item-sub">{{ log.message }}</p>
            <p class="item-sub">สถานะ: {{ log.status }} · {{ formatTime(log.createdAt) }}</p>
          </div>
        </div>
      </div>
    </div>
    </template>
  </div>
</template>

<script>
import { subscribeCollection, COLLECTIONS, SOS_ORDER_FIELD } from '@/service/firebase'

// The Flutter admin app's "Recent Logs" feed reads straight from the `sos` collection
// (admin_logs_screen.dart) — there's no separate `logs` collection to point at.
// `sos` docs use `name` and `timestamp`, so alias them to what this template expects.
function mapLog (row) {
  return Object.assign({}, row, {
    guardName: row.name || 'ไม่ทราบชื่อ',
    createdAt: row.timestamp
  })
}

export default {
  name: 'MfuSecurityLogs',
  data () {
    return {
      logs: [],
      unsubscribe: null,
      search: '',
      filter: 'all',
      loading: true,
      firebaseError: ''
    }
  },
  computed: {
    filteredLogs () {
      let rows = this.logs.map(mapLog)
      if (this.filter !== 'all') rows = rows.filter(l => l.status === this.filter)
      if (this.search) {
        const q = this.search.toLowerCase()
        rows = rows.filter(l => (l.guardName || '').toLowerCase().includes(q))
      }
      return rows
    }
  },
  mounted () {
    this.unsubscribe = subscribeCollection(COLLECTIONS.SOS, rows => {
      this.logs = rows
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
    formatTime (value) {
      if (!value || !value.toDate) return '-'
      return new Intl.DateTimeFormat('th-TH', { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(value.toDate())
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
