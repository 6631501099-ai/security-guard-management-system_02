<template>
  <div class="mfu-security">
    <div class="section-title">จัดการตารางงาน</div>
    <div v-if="errorMessage" class="alert alert-danger mfu-error">{{ errorMessage }}</div>

    <label class="field-label">เลือกเจ้าหน้าที่</label>
    <select class="select-field" v-model="selectedGuardUid">
      <option value="">ทั้งหมด</option>
      <option v-for="g in guardOptions" :key="g.uid" :value="g.uid">{{ g.name }}</option>
    </select>

    <div class="daynav">
      <button class="icon-btn" @click="shiftDay(-1)"><CIcon name="cil-chevron-left" /></button>
      <div class="dtext">{{ displayDate }}</div>
      <button class="icon-btn" @click="shiftDay(1)"><CIcon name="cil-chevron-right" /></button>
    </div>

    <div style="text-align:right;margin-bottom:14px;">
      <button class="btn-filled btn-primarydark" @click="openCreate">
        <CIcon name="cil-plus" />เพิ่มกะงาน
      </button>
    </div>

    <div class="list">
      <div v-if="!filteredShifts.length" class="mfu-empty">ไม่มีกะงานในวันที่เลือก</div>
      <div class="item-card" v-for="shift in filteredShifts" :key="shift.id">
        <div class="item-row">
          <CIcon name="cil-clock" style="color:var(--primary-dark)" />
          <div style="flex:1;">
            <p class="item-title">{{ shift.shiftName }} <span v-if="!selectedGuardUid">· {{ shift.guardName }}</span></p>
            <p class="item-sub">{{ shift.startTime }} - {{ shift.endTime }} น.</p>
            <p class="item-sub" v-if="shift.area">{{ shift.area }}</p>
          </div>
          <button class="icon-btn" style="color:var(--accent-red)" @click="removeShift(shift)">
            <CIcon name="cil-trash" />
          </button>
        </div>
      </div>
    </div>

    <div class="overlay" :class="{ show: creating }" @click.self="creating = false">
      <div class="sheet" v-if="creating">
        <div class="sheet-handle"></div>
        <h3 style="font-size:20px;font-weight:700;margin:0 0 14px;">เพิ่มกะงานใหม่</h3>
        <label class="field-label">เลือกเจ้าหน้าที่</label>
        <select class="select-field" v-model="form.guardUid">
          <option v-for="g in guardOptions" :key="g.uid" :value="g.uid">{{ g.name }}</option>
        </select>
        <label class="field-label">ชื่อกะงาน</label>
        <input class="select-field" v-model.trim="form.shiftName" placeholder="กะเช้า (S1)" />
        <label class="field-label">เวลาเริ่ม</label>
        <input class="select-field" v-model="form.startTime" type="time" />
        <label class="field-label">เวลาสิ้นสุด</label>
        <input class="select-field" v-model="form.endTime" type="time" />
        <label class="field-label">พื้นที่รับผิดชอบ</label>
        <input class="select-field" v-model.trim="form.area" placeholder="คุมพื้นที่ประตูหลังมหาวิทยาลัย" />
        <div style="display:flex;gap:10px;">
          <button class="btn-filled" style="flex:1;justify-content:center;background:var(--divider);color:var(--text-primary);" @click="creating = false">ยกเลิก</button>
          <button class="btn-filled btn-primarydark" style="flex:1;justify-content:center;" :disabled="saving" @click="saveShift">บันทึก</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { subscribeCollection, addDocument, deleteDocument, notifyGuard, COLLECTIONS } from '@/service/firebase'

function toDateKey (date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

// `schedules` docs on the Flutter side use `label`/`note` (not `shiftName`/`area`) —
// alias them here so the template can keep its existing field names.
function mapShift (row) {
  return Object.assign({}, row, {
    shiftName: row.label || '',
    area: row.note || ''
  })
}

const EMPTY_FORM = { guardUid: '', shiftName: '', startTime: '', endTime: '', area: '' }

export default {
  name: 'MfuSecuritySchedule',
  data () {
    return {
      guards: [],
      shifts: [],
      unsubscribers: [],
      currentDate: new Date(),
      selectedGuardUid: '',
      creating: false,
      saving: false,
      errorMessage: '',
      form: Object.assign({}, EMPTY_FORM)
    }
  },
  computed: {
    guardOptions () {
      return this.guards.map(g => ({ uid: g.id, name: g.name })).filter(g => g.name)
    },
    dateKey () {
      return toDateKey(this.currentDate)
    },
    displayDate () {
      const d = this.currentDate
      return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear() + 543}`
    },
    filteredShifts () {
      return this.shifts
        .map(mapShift)
        .filter(s => {
          if (s.date !== this.dateKey) return false
          // The guard's phone queries `schedules` by (guardUid, date) — see
          // guard_location_service.dart's watchScheduleForDay — so this dashboard
          // must key everything off guardUid too, not the display name.
          if (this.selectedGuardUid && s.guardUid !== this.selectedGuardUid) return false
          return true
        })
    }
  },
  mounted () {
    this.unsubscribers.push(
      subscribeCollection(COLLECTIONS.GUARDS, rows => { this.guards = rows }),
      subscribeCollection(COLLECTIONS.SCHEDULES, rows => { this.shifts = rows })
    )
  },
  beforeDestroy () {
    this.unsubscribers.forEach(unsub => unsub && unsub())
  },
  methods: {
    shiftDay (delta) {
      const next = new Date(this.currentDate)
      next.setDate(next.getDate() + delta)
      this.currentDate = next
    },
    openCreate () {
      const preselect = this.guardOptions.find(g => g.uid === this.selectedGuardUid) || this.guardOptions[0]
      this.form = Object.assign({}, EMPTY_FORM, { guardUid: preselect ? preselect.uid : '' })
      this.creating = true
    },
    async saveShift () {
      if (!this.form.guardUid) {
        this.errorMessage = 'กรุณาเลือกเจ้าหน้าที่'
        return
      }
      this.saving = true
      this.errorMessage = ''
      try {
        const picked = this.guardOptions.find(g => g.uid === this.form.guardUid)
        const payload = {
          guardUid: this.form.guardUid,
          guardName: picked ? picked.name : '',
          date: this.dateKey,
          label: this.form.shiftName,
          startTime: this.form.startTime,
          endTime: this.form.endTime,
          note: this.form.area
        }
        await addDocument(COLLECTIONS.SCHEDULES, payload)
        await notifyGuard(payload.guardUid, {
          title: 'ตารางเวรมีการอัปเดต',
          subtitle: `${payload.label} วันที่ ${this.currentDate.getDate()}/${this.currentDate.getMonth() + 1}`,
          category: 'notice'
        })
        this.creating = false
      } catch (error) {
        this.errorMessage = 'ไม่สามารถบันทึกกะงานได้ กรุณาลองใหม่'
      } finally {
        this.saving = false
      }
    },
    async removeShift (shift) {
      try {
        await deleteDocument(COLLECTIONS.SCHEDULES, shift.id)
      } catch (error) {
        this.errorMessage = 'ไม่สามารถลบกะงานได้ กรุณาลองใหม่'
      }
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
