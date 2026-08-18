<template>
  <div class="mfu-security">
    <div class="section-title">รายงานเหตุการณ์</div>
    <div v-if="errorMessage" class="alert alert-danger mfu-error">{{ errorMessage }}</div>

    <div class="chips">
      <div class="fchip" :class="{ on: filter === 'new' }" @click="filter = 'new'">ใหม่</div>
      <div class="fchip" :class="{ on: filter === 'reviewed' }" @click="filter = 'reviewed'">ตรวจแล้ว</div>
      <div class="fchip" :class="{ on: filter === 'all' }" @click="filter = 'all'">ทั้งหมด</div>
    </div>

    <div class="list">
      <div v-if="!filteredIncidents.length" class="mfu-empty">ไม่มีรายงานเหตุการณ์</div>
      <div class="item-card" v-for="incident in filteredIncidents" :key="incident.id" style="cursor:pointer;" @click="selected = incident">
        <div class="item-row">
          <div class="avatar-circle" style="background:var(--warning)">
            <CIcon name="cil-warning" />
          </div>
          <div style="flex:1;">
            <p class="item-title">{{ incident.title }}</p>
            <p class="item-sub">{{ incident.reporter }}</p>
            <p class="item-sub" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">{{ incident.description }}</p>
          </div>
          <span
            class="pill"
            :style="incident.status === 'reviewed'
              ? 'background:rgba(46,125,50,.12);color:var(--success)'
              : 'background:rgba(212,175,55,.16);color:var(--warning)'"
          >{{ incident.status === 'reviewed' ? 'ตรวจแล้ว' : 'ใหม่' }}</span>
        </div>
      </div>
    </div>

    <div class="overlay" :class="{ show: !!selected }" @click.self="selected = null">
      <div class="sheet" v-if="selected">
        <div class="sheet-handle"></div>
        <h3 style="font-size:20px;font-weight:700;margin:0 0 10px;">{{ selected.title }}</h3>
        <p style="margin:4px 0;font-size:14.5px;">เจ้าหน้าที่: {{ selected.reporter }}</p>
        <p style="margin:4px 0;font-size:14.5px;">รายละเอียด: {{ selected.description }}</p>
        <p style="margin:4px 0;font-size:14.5px;">ตำแหน่ง: {{ selected.lat }}, {{ selected.lng }}</p>
        <div class="sheet-photo" v-if="selected.photoUrl" :style="{ backgroundImage: 'url(' + selected.photoUrl + ')', backgroundSize: 'cover' }"></div>
        <div class="sheet-photo" v-else></div>
        <button
          class="btn-filled btn-success"
          style="width:100%;justify-content:center;margin-top:18px;height:46px;"
          :disabled="selected.status === 'reviewed'"
          @click="markReviewed"
        >
          <CIcon name="cil-check" />ทำเครื่องหมายว่าตรวจแล้ว
        </button>
      </div>
    </div>
  </div>
</template>

<script>
import { subscribeCollection, updateDocument, COLLECTIONS } from '@/service/firebase'

// `incidents` docs written by the Flutter guard app use `type`/`guardName` (not
// `title`/`reporter`) — alias them here so the template can keep its existing names.
function mapIncident (row) {
  return Object.assign({}, row, {
    title: row.type || 'เหตุการณ์',
    reporter: row.guardName || 'ไม่ทราบชื่อ'
  })
}

export default {
  name: 'MfuSecurityIncidents',
  data () {
    return {
      incidents: [],
      unsubscribe: null,
      filter: 'new',
      selected: null,
      errorMessage: ''
    }
  },
  computed: {
    filteredIncidents () {
      const rows = this.incidents.map(mapIncident)
      if (this.filter === 'all') return rows
      return rows.filter(i => (i.status || 'new') === this.filter)
    }
  },
  mounted () {
    this.unsubscribe = subscribeCollection(COLLECTIONS.INCIDENTS, rows => { this.incidents = rows }, { orderByField: 'createdAt' })
  },
  beforeDestroy () {
    if (this.unsubscribe) this.unsubscribe()
  },
  methods: {
    async markReviewed () {
      if (!this.selected) return
      try {
        await updateDocument(COLLECTIONS.INCIDENTS, this.selected.id, { status: 'reviewed' })
        this.selected = Object.assign({}, this.selected, { status: 'reviewed' })
      } catch (error) {
        this.errorMessage = 'ไม่สามารถอัปเดตสถานะเหตุการณ์ได้'
      }
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
