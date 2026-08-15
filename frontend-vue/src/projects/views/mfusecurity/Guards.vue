<template>
  <div class="mfu-security">
    <div class="row-top">
      <div class="section-title" style="flex:1;">รายชื่อการ์ด</div>
      <button class="btn-filled btn-primarydark" @click="openCreate">
        <CIcon name="cil-plus" />เพิ่มการ์ด
      </button>
    </div>

    <div v-if="errorMessage" class="alert alert-danger mfu-error">{{ errorMessage }}</div>

    <div class="search-field" style="margin-bottom:12px;">
      <CIcon name="cil-search" />
      <input v-model.trim="search" placeholder="ค้นหาอีเมลเจ้าหน้าที่การ์ด" />
    </div>
    <div class="chips">
      <div class="fchip" :class="{ on: filter === 'all' }" @click="filter = 'all'">ทั้งหมด</div>
      <div class="fchip" :class="{ on: filter === 'in' }" @click="filter = 'in'">ในพื้นที่</div>
      <div class="fchip" :class="{ on: filter === 'out' }" @click="filter = 'out'">นอกพื้นที่</div>
    </div>

    <div class="list">
      <div v-if="!filteredGuards.length" class="mfu-empty">ไม่พบข้อมูลเจ้าหน้าที่การ์ด</div>
      <div class="item-card" v-for="guard in filteredGuards" :key="guard.id">
        <div class="item-row">
          <div class="avatar-circle" :style="{ background: guard.status === 'out_of_scope' ? 'var(--accent-red)' : 'var(--success)' }">
            <CIcon name="cil-shield-alt" />
          </div>
          <div style="flex:1;">
            <p class="item-title">{{ guard.name }}</p>
            <p class="item-sub">{{ guard.email }}</p>
            <p class="item-sub">Lat: {{ guard.lat }} • Lng: {{ guard.lng }}</p>
            <span
              class="pill"
              :style="guard.status === 'out_of_scope'
                ? 'background:rgba(229,57,53,.12);color:var(--accent-red);margin-top:6px;'
                : 'background:rgba(46,125,50,.12);color:var(--success);margin-top:6px;'"
            >{{ guard.status === 'out_of_scope' ? 'out of scope' : 'on route' }}</span>
          </div>
          <button class="action-btn" style="background:var(--primary-dark)" @click="openDetail(guard)">
            <CIcon name="cil-zoom" />ดูรายละเอียด
          </button>
        </div>
      </div>
    </div>

    <div class="overlay" :class="{ show: !!selected }" @click.self="closeSheet">
      <div class="sheet" v-if="selected">
        <div class="sheet-handle"></div>

        <template v-if="!editing">
          <div class="sheet-title-row">
            <div class="avatar-circle" :style="{ background: selected.status === 'out_of_scope' ? 'var(--accent-red)' : 'var(--success)' }">
              <CIcon name="cil-shield-alt" />
            </div>
            <h3>{{ selected.name }}</h3>
          </div>
          <div class="drow"><div class="k">อีเมล</div><div class="v">{{ selected.email }}</div></div>
          <div class="drow"><div class="k">ละติจูด</div><div class="v">{{ selected.lat }}</div></div>
          <div class="drow"><div class="k">ลองจิจูด</div><div class="v">{{ selected.lng }}</div></div>
          <div style="margin-top:12px;">
            <span
              class="pill"
              :style="selected.status === 'out_of_scope'
                ? 'background:rgba(229,57,53,.12);color:var(--accent-red)'
                : 'background:rgba(46,125,50,.12);color:var(--success)'"
            >{{ selected.status === 'out_of_scope' ? 'out of scope' : 'on route' }}</span>
          </div>
          <div class="sheet-actions">
            <button class="action-btn" style="background:var(--primary-dark)" @click="$router.push('/mfu-security/tracking')">
              <CIcon name="cil-location-pin" />ระบุพิกัด
            </button>
            <button class="action-btn" style="background:var(--info)">
              <CIcon name="cil-phone" />โทรหาการ์ด
            </button>
            <button class="action-btn" style="background:var(--warning)" @click="startEdit">
              <CIcon name="cil-pencil" />แก้ไข
            </button>
            <button class="action-btn" style="background:var(--accent-red)" :disabled="saving" @click="removeGuard">
              <CIcon name="cil-trash" />ลบออก
            </button>
          </div>
        </template>

        <template v-else>
          <h3 style="font-size:20px;font-weight:700;margin:0 0 14px;">{{ form.id ? 'แก้ไขข้อมูลการ์ด' : 'เพิ่มการ์ดใหม่' }}</h3>
          <label class="field-label">ชื่อ - นามสกุล</label>
          <input class="select-field" v-model.trim="form.name" placeholder="ชื่อเจ้าหน้าที่การ์ด" />
          <label class="field-label">อีเมล</label>
          <input class="select-field" v-model.trim="form.email" type="email" placeholder="name@mfu.ac.th" />
          <label class="field-label">ละติจูด</label>
          <input class="select-field" v-model.trim="form.lat" placeholder="20.0445" />
          <label class="field-label">ลองจิจูด</label>
          <input class="select-field" v-model.trim="form.lng" placeholder="99.8942" />
          <label class="field-label">สถานะ</label>
          <select class="select-field" v-model="form.status">
            <option value="on_route">on route</option>
            <option value="out_of_scope">out of scope</option>
          </select>
          <div style="display:flex;gap:10px;">
            <button class="btn-filled" style="flex:1;justify-content:center;background:var(--divider);color:var(--text-primary);" @click="cancelEdit">ยกเลิก</button>
            <button class="btn-filled btn-primarydark" style="flex:1;justify-content:center;" :disabled="saving" @click="saveGuard">บันทึก</button>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<script>
import { subscribeCollection, addDocument, updateDocument, deleteDocument, COLLECTIONS } from '@/service/firebase'

const EMPTY_FORM = { id: '', name: '', email: '', lat: '', lng: '', status: 'on_route' }

export default {
  name: 'MfuSecurityGuards',
  data () {
    return {
      guards: [],
      unsubscribe: null,
      search: '',
      filter: 'all',
      selected: null,
      editing: false,
      saving: false,
      errorMessage: '',
      form: Object.assign({}, EMPTY_FORM)
    }
  },
  computed: {
    filteredGuards () {
      let rows = this.guards
      if (this.filter === 'in') rows = rows.filter(g => g.status !== 'out_of_scope')
      if (this.filter === 'out') rows = rows.filter(g => g.status === 'out_of_scope')
      if (this.search) {
        const q = this.search.toLowerCase()
        rows = rows.filter(g => (g.email || '').toLowerCase().includes(q) || (g.name || '').toLowerCase().includes(q))
      }
      return rows
    }
  },
  mounted () {
    this.unsubscribe = subscribeCollection(COLLECTIONS.GUARDS, rows => { this.guards = rows })
  },
  beforeDestroy () {
    if (this.unsubscribe) this.unsubscribe()
  },
  methods: {
    openDetail (guard) {
      this.selected = guard
      this.editing = false
    },
    openCreate () {
      this.form = Object.assign({}, EMPTY_FORM)
      this.selected = {}
      this.editing = true
    },
    startEdit () {
      this.form = Object.assign({}, EMPTY_FORM, this.selected)
      this.editing = true
    },
    cancelEdit () {
      if (this.form.id) {
        this.editing = false
      } else {
        this.closeSheet()
      }
    },
    closeSheet () {
      this.selected = null
      this.editing = false
    },
    async saveGuard () {
      this.saving = true
      this.errorMessage = ''
      try {
        const payload = {
          name: this.form.name,
          email: this.form.email,
          lat: Number(this.form.lat) || 0,
          lng: Number(this.form.lng) || 0,
          status: this.form.status
        }
        if (this.form.id) {
          await updateDocument(COLLECTIONS.GUARDS, this.form.id, payload)
        } else {
          await addDocument(COLLECTIONS.GUARDS, payload)
        }
        this.closeSheet()
      } catch (error) {
        this.errorMessage = 'ไม่สามารถบันทึกข้อมูลการ์ดได้ กรุณาลองใหม่'
      } finally {
        this.saving = false
      }
    },
    async removeGuard () {
      if (!this.selected || !this.selected.id) return
      this.saving = true
      this.errorMessage = ''
      try {
        await deleteDocument(COLLECTIONS.GUARDS, this.selected.id)
        this.closeSheet()
      } catch (error) {
        this.errorMessage = 'ไม่สามารถลบข้อมูลการ์ดได้ กรุณาลองใหม่'
      } finally {
        this.saving = false
      }
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
