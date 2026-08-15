<template>
  <div class="mfu-security">
    <div class="section-title">จัดการตารางงาน</div>
    <div v-if="errorMessage" class="alert alert-danger mfu-error">{{ errorMessage }}</div>

    <label class="field-label">เลือกเจ้าหน้าที่</label>
    <select class="select-field" v-model="selectedGuardName">
      <option value="">ทั้งหมด</option>
      <option v-for="name in guardNames" :key="name" :value="name">{{ name }}</option>
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
            <p class="item-title">{{ shift.shiftName }} <span v-if="!selectedGuardName">· {{ shift.guardName }}</span></p>
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
        <select class="select-field" v-model="form.guardName">
          <option v-for="name in guardNames" :key="name" :value="name">{{ name }}</option>
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
import { subscribeCollection, addDocument, deleteDocument, COLLECTIONS } from '@/service/firebase'

function toDateKey (date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

const EMPTY_FORM = { guardName: '', shiftName: '', startTime: '', endTime: '', area: '' }

export default {
  name: 'MfuSecuritySchedule',
  data () {
    return {
      guards: [],
      shifts: [],
      unsubscribers: [],
      currentDate: new Date(),
      selectedGuardName: '',
      creating: false,
      saving: false,
      errorMessage: '',
      form: Object.assign({}, EMPTY_FORM)
    }
  },
  computed: {
    guardNames () {
      return this.guards.map(g => g.name).filter(Boolean)
    },
    dateKey () {
      return toDateKey(this.currentDate)
    },
    displayDate () {
      const d = this.currentDate
      return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear() + 543}`
    },
    filteredShifts () {
      return this.shifts.filter(s => {
        if (s.date !== this.dateKey) return false
        if (this.selectedGuardName && s.guardName !== this.selectedGuardName) return false
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
      this.form = Object.assign({}, EMPTY_FORM, { guardName: this.selectedGuardName || this.guardNames[0] || '' })
      this.creating = true
    },
    async saveShift () {
      this.saving = true
      this.errorMessage = ''
      try {
        await addDocument(COLLECTIONS.SCHEDULES, Object.assign({}, this.form, { date: this.dateKey }))
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
