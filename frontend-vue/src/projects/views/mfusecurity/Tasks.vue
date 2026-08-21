<template>
  <div class="mfu-security">
    <div class="row-top">
      <div class="section-title">มอบหมายงาน</div>
      <button class="btn-filled btn-primarydark" @click="openCreate">
        <CIcon name="cil-playlist-add" />มอบหมายงาน
      </button>
    </div>
    <div v-if="loading" style="text-align:center;padding:40px;color:var(--text-secondary);">
      <div class="mfu-spinner"></div>
      <p style="margin-top:12px;">กำลังโหลดงานจาก Firebase...</p>
    </div>
    <div v-else-if="firebaseError" class="alert alert-danger mfu-error">{{ firebaseError }}</div>
    <template v-else>
    <div v-if="errorMessage" class="alert alert-danger mfu-error">{{ errorMessage }}</div>

    <div class="chips">
      <div class="fchip" :class="{ on: filter === 'all' }" @click="filter = 'all'">ทั้งหมด</div>
      <div class="fchip" :class="{ on: filter === 'pending' }" @click="filter = 'pending'">ยังไม่เสร็จ</div>
      <div class="fchip" :class="{ on: filter === 'done' }" @click="filter = 'done'">เสร็จแล้ว</div>
    </div>

    <div class="list">
      <div v-if="!filteredTasks.length" class="mfu-empty">ไม่มีงานที่มอบหมาย</div>
      <div class="item-card" v-for="task in filteredTasks" :key="task.id">
        <div class="item-row">
          <button class="icon-btn" :style="{ color: task.done ? 'var(--success)' : 'var(--warning)' }" @click="toggleDone(task)" title="ทำเครื่องหมายว่าเสร็จ">
            <CIcon :name="task.done ? 'cil-check-circle' : 'cil-clock'" />
          </button>
          <div style="flex:1;">
            <p class="item-title">{{ task.title }}</p>
            <p class="item-sub">{{ task.assignee }}</p>
            <p class="item-sub">
              {{ task.time }} น. • {{ task.date }}
              <span class="repeat-badge" v-if="task.repeatDays && task.repeatDays.length">
                <span class="rb-day" v-for="d in dayLabels" :key="d" :class="{ on: task.repeatDays.includes(d) }">{{ d }}</span>
              </span>
            </p>
          </div>
          <button class="icon-btn" style="color:var(--accent-red)" @click="removeTask(task)">
            <CIcon name="cil-trash" />
          </button>
        </div>
      </div>
    </div>
    </template>

    <div class="overlay" :class="{ show: creating }" @click.self="creating = false">
      <div class="sheet" v-if="creating">
        <div class="sheet-handle"></div>
        <h3 style="font-size:20px;font-weight:700;margin:0 0 14px;">มอบหมายงานใหม่</h3>
        <label class="field-label">เลือกเจ้าหน้าที่</label>
        <select class="select-field" v-model="form.guardUid">
          <option v-for="g in guardOptions" :key="g.uid" :value="g.uid">{{ g.name }}</option>
        </select>
        <label class="field-label">ชื่องาน</label>
        <input class="select-field" v-model.trim="form.title" placeholder="ตรวจสอบไฟส่องสว่างบริเวณลานจอดรถ C" />
        <label class="field-label">เวลา</label>
        <input class="select-field" v-model="form.time" type="time" />
        <label class="field-label">วันที่</label>
        <input class="select-field" v-model="form.date" type="date" />
        <div class="repeat-box">
          <div class="toggle-row">
            <div>
              <div class="tt">ทำซ้ำทุกสัปดาห์</div>
              <div class="ts">งานจะถูกสร้างอัตโนมัติทุกวันที่เลือกไว้ (คล้ายตั้งปลุก)</div>
            </div>
            <div class="toggle" :class="{ on: form.repeatWeekly }" @click="form.repeatWeekly = !form.repeatWeekly">
              <div class="knob"></div>
            </div>
          </div>
          <div class="day-picker" v-if="form.repeatWeekly">
            <div
              class="day-btn"
              v-for="d in dayLabels"
              :key="d"
              :class="{ selected: form.repeatDays.includes(d) }"
              @click="toggleDay(d)"
            >{{ d }}</div>
          </div>
        </div>
        <div style="display:flex;gap:10px;">
          <button class="btn-filled" style="flex:1;justify-content:center;background:var(--divider);color:var(--text-primary);" @click="creating = false">ยกเลิก</button>
          <button class="btn-filled btn-primarydark" style="flex:1;justify-content:center;" :disabled="saving" @click="saveTask">มอบหมาย</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { subscribeCollection, addDocument, updateDocument, deleteDocument, notifyGuard, COLLECTIONS } from '@/service/firebase'

const DAY_LABELS = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'] // index matches JS Date#getDay()
const REPEAT_WEEKS = 8 // how many weeks ahead to generate recurring task instances
const EMPTY_FORM = { guardUid: '', title: '', time: '', date: '', repeatWeekly: false, repeatDays: [] }

function toDateKey (date) {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

// `tasks` docs on the Flutter side use `guardName`/`timeRange` (not `assignee`/`time`) —
// alias them here so the template can keep its existing field names.
function mapTask (row) {
  return Object.assign({}, row, {
    assignee: row.guardName || '',
    time: row.timeRange || ''
  })
}

export default {
  name: 'MfuSecurityTasks',
  data () {
    return {
      guards: [],
      tasks: [],
      unsubscribers: [],
      filter: 'pending',
      creating: false,
      saving: false,
      loading: true,
      firebaseError: '',
      errorMessage: '',
      dayLabels: DAY_LABELS,
      form: Object.assign({}, EMPTY_FORM)
    }
  },
  computed: {
    guardOptions () {
      return this.guards.map(g => ({ uid: g.id, name: g.name })).filter(g => g.name)
    },
    mappedTasks () {
      return this.tasks.map(mapTask)
    },
    filteredTasks () {
      if (this.filter === 'pending') return this.mappedTasks.filter(t => !t.done)
      if (this.filter === 'done') return this.mappedTasks.filter(t => t.done)
      return this.mappedTasks
    }
  },
  mounted () {
    const handleErr = err => {
      this.loading = false
      this.firebaseError = (err && err.message) ? err.message : 'ไม่สามารถเชื่อมต่อ Firebase ได้'
    }
    this.unsubscribers.push(
      subscribeCollection(COLLECTIONS.GUARDS, rows => { this.guards = rows }, { onError: handleErr }),
      subscribeCollection(COLLECTIONS.TASKS, rows => {
        this.tasks = rows
        this.loading = false
      }, { orderByField: 'createdAt', onError: handleErr })
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
  },
  methods: {
    openCreate () {
      const today = new Date().toISOString().slice(0, 10)
      this.form = Object.assign({}, EMPTY_FORM, { guardUid: this.guardOptions[0] ? this.guardOptions[0].uid : '', date: today })
      this.creating = true
    },
    toggleDay (day) {
      const idx = this.form.repeatDays.indexOf(day)
      if (idx >= 0) this.form.repeatDays.splice(idx, 1)
      else this.form.repeatDays.push(day)
    },
    // The Flutter guard app's task screen (guard_tasks_screen.dart) just reads flat
    // `tasks` docs per guardUid — there's no "recurring task" field/concept on that
    // side. To keep "ทำซ้ำทุกสัปดาห์" working without any Flutter changes, this
    // generates one plain task doc per matching weekday over the next REPEAT_WEEKS
    // weeks instead of storing a repeat rule that nothing else understands.
    generateDates () {
      if (!this.form.repeatWeekly || !this.form.repeatDays.length) {
        return [this.form.date]
      }
      const dates = []
      const start = new Date(this.form.date + 'T00:00:00')
      const totalDays = REPEAT_WEEKS * 7
      for (let i = 0; i < totalDays; i++) {
        const d = new Date(start)
        d.setDate(d.getDate() + i)
        if (this.form.repeatDays.includes(DAY_LABELS[d.getDay()])) {
          dates.push(toDateKey(d))
        }
      }
      return dates.length ? dates : [this.form.date]
    },
    async saveTask () {
      if (!this.form.guardUid) {
        this.errorMessage = 'กรุณาเลือกเจ้าหน้าที่'
        return
      }
      this.saving = true
      this.errorMessage = ''
      try {
        const picked = this.guardOptions.find(g => g.uid === this.form.guardUid)
        const guardName = picked ? picked.name : ''
        const dates = this.generateDates()
        await Promise.all(dates.map(date => addDocument(COLLECTIONS.TASKS, {
          guardUid: this.form.guardUid,
          guardName,
          title: this.form.title,
          timeRange: this.form.time,
          date,
          done: false
        })))
        await notifyGuard(this.form.guardUid, {
          title: 'มีงานใหม่ได้รับมอบหมาย',
          subtitle: this.form.title,
          category: 'notice'
        })
        this.creating = false
      } catch (error) {
        this.errorMessage = 'ไม่สามารถมอบหมายงานได้ กรุณาลองใหม่'
      } finally {
        this.saving = false
      }
    },
    async toggleDone (task) {
      try {
        await updateDocument(COLLECTIONS.TASKS, task.id, { done: !task.done })
      } catch (error) {
        this.errorMessage = 'ไม่สามารถอัปเดตสถานะงานได้'
      }
    },
    async removeTask (task) {
      try {
        await deleteDocument(COLLECTIONS.TASKS, task.id)
      } catch (error) {
        this.errorMessage = 'ไม่สามารถลบงานได้'
      }
    }
  }
}
</script>

<style scoped lang="scss">
@import "./mfu-security.shared.scss";
</style>
