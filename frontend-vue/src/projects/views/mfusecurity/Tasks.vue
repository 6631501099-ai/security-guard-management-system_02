<template>
  <div class="mfu-security">
    <div class="row-top">
      <div class="section-title">มอบหมายงาน</div>
      <button class="btn-filled btn-primarydark" @click="openCreate">
        <CIcon name="cil-playlist-add" />มอบหมายงาน
      </button>
    </div>
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

    <div class="overlay" :class="{ show: creating }" @click.self="creating = false">
      <div class="sheet" v-if="creating">
        <div class="sheet-handle"></div>
        <h3 style="font-size:20px;font-weight:700;margin:0 0 14px;">มอบหมายงานใหม่</h3>
        <label class="field-label">เลือกเจ้าหน้าที่</label>
        <select class="select-field" v-model="form.assignee">
          <option v-for="name in guardNames" :key="name" :value="name">{{ name }}</option>
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
import { subscribeCollection, addDocument, updateDocument, deleteDocument, COLLECTIONS } from '@/service/firebase'

const DAY_LABELS = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส']
const EMPTY_FORM = { assignee: '', title: '', time: '', date: '', repeatWeekly: false, repeatDays: [] }

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
      errorMessage: '',
      dayLabels: DAY_LABELS,
      form: Object.assign({}, EMPTY_FORM)
    }
  },
  computed: {
    guardNames () {
      return this.guards.map(g => g.name).filter(Boolean)
    },
    filteredTasks () {
      if (this.filter === 'pending') return this.tasks.filter(t => !t.done)
      if (this.filter === 'done') return this.tasks.filter(t => t.done)
      return this.tasks
    }
  },
  mounted () {
    this.unsubscribers.push(
      subscribeCollection(COLLECTIONS.GUARDS, rows => { this.guards = rows }),
      subscribeCollection(COLLECTIONS.TASKS, rows => { this.tasks = rows }, { orderByField: 'createdAt' })
    )
  },
  beforeDestroy () {
    this.unsubscribers.forEach(unsub => unsub && unsub())
  },
  methods: {
    openCreate () {
      const today = new Date().toISOString().slice(0, 10)
      this.form = Object.assign({}, EMPTY_FORM, { assignee: this.guardNames[0] || '', date: today })
      this.creating = true
    },
    toggleDay (day) {
      const idx = this.form.repeatDays.indexOf(day)
      if (idx >= 0) this.form.repeatDays.splice(idx, 1)
      else this.form.repeatDays.push(day)
    },
    async saveTask () {
      this.saving = true
      this.errorMessage = ''
      try {
        const payload = {
          assignee: this.form.assignee,
          title: this.form.title,
          time: this.form.time,
          date: this.form.date,
          repeatDays: this.form.repeatWeekly ? this.form.repeatDays : [],
          done: false
        }
        await addDocument(COLLECTIONS.TASKS, payload)
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
