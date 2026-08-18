<template>
  <div class="mfu-security">
    <div class="row-top">
      <div class="section-title" style="flex:1;">รายชื่อการ์ด</div>
    </div>

    <p class="body-text" style="margin:-4px 0 14px;color:var(--text-secondary);">
      รายชื่อนี้แสดงเฉพาะการ์ดที่เข้าสู่ระบบและเช็คอินภายใน 1 นาทีที่ผ่านมา (ตรงกับแอปแอดมิน)
      บัญชีการ์ดใหม่ต้องลงทะเบียนผ่านแอปมือถือเท่านั้น — ไม่สามารถสร้างบัญชีจากหน้านี้ได้
    </p>

    <div v-if="errorMessage" class="alert alert-danger mfu-error">{{ errorMessage }}</div>

    <div class="search-field" style="margin-bottom:12px;">
      <CIcon name="cil-search" />
      <input v-model.trim="search" placeholder="ค้นหาชื่อ/อีเมลเจ้าหน้าที่การ์ด" />
    </div>
    <div class="chips">
      <div class="fchip" :class="{ on: filter === 'all' }" @click="filter = 'all'">ทั้งหมด</div>
      <div class="fchip" :class="{ on: filter === 'in' }" @click="filter = 'in'">ในพื้นที่</div>
      <div class="fchip" :class="{ on: filter === 'out' }" @click="filter = 'out'">นอกพื้นที่</div>
    </div>

    <div class="list">
      <div v-if="!filteredGuards.length" class="mfu-empty">ไม่พบเจ้าหน้าที่การ์ดที่กำลังออนไลน์</div>
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
          <div class="drow"><div class="k">เบอร์โทร</div><div class="v">{{ selected.phone || '-' }}</div></div>
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
          <h3 style="font-size:20px;font-weight:700;margin:0 0 14px;">แก้ไขข้อมูลการ์ด</h3>
          <!--
            Only name + phone are editable here — that matches what the real system
            actually supports (GuardActions.updateGuardProfile on the Flutter side writes
            these two fields to both `users/{uid}` and `locations/{uid}`). Latitude,
            longitude, and online/out-of-scope status are live telemetry the guard's own
            phone reports automatically; they were editable here before, but hand-editing
            them would just get silently overwritten by the guard's phone on its next
            location update (or several seconds), so there's no real reason to expose
            them as form fields.
          -->
          <label class="field-label">ชื่อ - นามสกุล</label>
          <input class="select-field" v-model.trim="form.name" placeholder="ชื่อเจ้าหน้าที่การ์ด" />
          <label class="field-label">เบอร์โทร</label>
          <input class="select-field" v-model.trim="form.phone" placeholder="08X-XXX-XXXX" />
          <p class="body-text" style="margin-top:-6px;color:var(--text-secondary);">อีเมล: {{ selected.email }} (แก้ไขไม่ได้ — ผูกกับบัญชีเข้าสู่ระบบของการ์ด)</p>
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
import { subscribeCollection, updateDocument, deleteDocument, isGuardOnline, COLLECTIONS } from '@/service/firebase'

// `locations` docs use `outOfScope: boolean` (not a `status` string); `phone` actually
// lives on the separate `users/{uid}` profile doc, not on `locations` at all — merge
// both here so the template can keep treating a "guard" as one flat object.
function mapGuard (row, usersById) {
  const profile = usersById[row.id] || {}
  return Object.assign({}, row, {
    status: row.outOfScope === true ? 'out_of_scope' : 'on_route',
    phone: profile.phone || ''
  })
}

const EMPTY_FORM = { id: '', name: '', phone: '' }

export default {
  name: 'MfuSecurityGuards',
  data () {
    return {
      guards: [],
      users: [],
      unsubscribers: [],
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
    usersById () {
      const map = {}
      this.users.forEach(u => { map[u.id] = u })
      return map
    },
    // Same 60-second freshness rule as the Flutter admin app's roster — a guard whose
    // phone hasn't reported in over a minute is treated as off-shift and drops off this
    // list, even if `working` is still true in Firestore.
    onlineGuards () {
      return this.guards.filter(isGuardOnline).map(g => mapGuard(g, this.usersById))
    },
    filteredGuards () {
      let rows = this.onlineGuards
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
    this.unsubscribers.push(
      subscribeCollection(COLLECTIONS.GUARDS, rows => { this.guards = rows }),
      subscribeCollection(COLLECTIONS.USERS, rows => { this.users = rows })
    )
  },
  beforeDestroy () {
    this.unsubscribers.forEach(unsub => unsub && unsub())
  },
  methods: {
    openDetail (guard) {
      this.selected = guard
      this.editing = false
    },
    startEdit () {
      this.form = { id: this.selected.id, name: this.selected.name || '', phone: this.selected.phone || '' }
      this.editing = true
    },
    cancelEdit () {
      this.editing = false
    },
    closeSheet () {
      this.selected = null
      this.editing = false
    },
    async saveGuard () {
      if (!this.form.id) return
      this.saving = true
      this.errorMessage = ''
      try {
        // Mirrors GuardActions.updateGuardProfile on the Flutter side: name/phone go to
        // BOTH `users/{uid}` (the guard app's own profile) and `locations/{uid}` (so the
        // roster label here and on Live Tracking update immediately).
        await updateDocument(COLLECTIONS.USERS, this.form.id, { name: this.form.name, phone: this.form.phone })
        await updateDocument(COLLECTIONS.GUARDS, this.form.id, { name: this.form.name })
        this.editing = false
      } catch (error) {
        this.errorMessage = 'ไม่สามารถบันทึกข้อมูลการ์ดได้ กรุณาลองใหม่'
      } finally {
        this.saving = false
      }
    },
    async removeGuard () {
      if (!this.selected || !this.selected.id) return
      // eslint-disable-next-line no-alert
      if (!window.confirm(`นำ "${this.selected.name}" ออกจากรายชื่อและการติดตามสด ใช่หรือไม่?`)) return
      this.saving = true
      this.errorMessage = ''
      try {
        // Matches GuardActions.deleteGuard — this only removes the guard from the
        // active roster/live tracking + profile doc. It does NOT delete their Firebase
        // Auth login (that needs the Admin SDK / Firebase Console — same limitation the
        // Flutter admin app has). Their login will still work; to fully deactivate them,
        // disable the account from the Firebase Console's Authentication tab too.
        await deleteDocument(COLLECTIONS.GUARDS, this.selected.id)
        await deleteDocument(COLLECTIONS.USERS, this.selected.id)
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
