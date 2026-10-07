<template>
  <div class="week-details">
  <div class="table-wrap desktop-hours">
    <table class="table week-table">
      <thead>
        <tr>
          <th scope="col">Jour</th>
          <th scope="col">Arrivée</th>
          <th scope="col">Départ</th>
          <th scope="col">Durée</th>
          <th scope="col">Type d’heures</th>
          <th scope="col">État</th>
        </tr>
      </thead>
      <tbody>
        <template v-for="day in rows" :key="day.key">
          <tr v-if="day.entries.length === 0">
            <th scope="row">{{ day.label }}</th>
            <td class="num">{{ day.key === pendingDay ? clock(missingDeparture.arrival.time) : '—' }}</td>
            <td>—</td>
            <td>—</td>
            <td class="muted">{{ day.key === pendingDay ? 'À compléter' : 'Repos' }}</td>
            <td>
              <span v-if="day.key === pendingDay">Départ non pointé</span>
              <button v-else-if="day.editable" class="btn btn-quiet btn-sm" type="button" @click="$emit('create', day.key)">Ajouter</button>
            </td>
          </tr>
          <tr v-for="(entry, index) in day.entries" :key="entry.id || `${day.key}-${index}`">
            <th scope="row">{{ index === 0 ? day.label : '' }}</th>
            <td class="num">{{ clock(entry.start) }}</td>
            <td class="num">{{ clock(entry.end) }}</td>
            <td class="num">{{ duration(entry.hours) }}</td>
            <td><HourTag :kind="entry.kind" short /></td>
            <td>
              <div class="state">
                <span class="pill pill-ok"><AppIcon name="check" />Enregistré</span>
                <button v-if="canRequest" class="btn btn-quiet btn-sm" type="button" @click="$emit('request', entry.id)">Proposer une correction</button>
                <button v-if="entry.editable" class="btn btn-quiet btn-sm" type="button" @click="$emit('edit', entry.id)">Corriger</button>
              </div>
            </td>
          </tr>
        </template>

      </tbody>
    </table>
  </div>
  <div class="mobile-hours"><article v-for="day in rows" :key="day.key" class="card day-card"><header><strong>{{ day.label }}</strong><span class="pill" :class="day.key === pendingDay ? 'pill-warn' : 'pill-ok'">{{ day.key === pendingDay ? 'À régulariser' : day.entries.length ? 'Confirmé' : 'Repos' }}</span></header><p v-if="!day.entries.length" class="muted">{{ day.key === pendingDay ? `Arrivée ${clock(missingDeparture.arrival.time)} · départ à compléter` : 'Aucune période enregistrée' }}</p><div v-for="entry in day.entries" :key="entry.id" class="mobile-entry"><div class="entry-summary"><span class="num">{{ clock(entry.start) }} → {{ clock(entry.end) }}</span><HourTag :kind="entry.kind" :hours="entry.hours" /></div><button v-if="canRequest" class="btn btn-outline btn-sm" type="button" @click="$emit('request', entry.id)">Proposer une correction</button><button v-if="entry.editable" class="btn btn-quiet btn-sm" type="button" @click="$emit('edit', entry.id)">Corriger</button></div><button v-if="!day.entries.length && day.editable" class="btn btn-quiet btn-sm" type="button" @click="$emit('create', day.key)">Ajouter une période</button></article></div>
  <MissingDeparture v-if="userId" :user-id="userId" :now="now" :week-start="monday" @detected="missingDeparture = $event" @completed="$emit('completed')" @refreshed="$emit('completed')" />
  </div>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import HourTag from '../ui/HourTag.vue'
import MissingDeparture from '../MissingDeparture.vue'
import { clockDate } from '../../utils/missingDeparture'
import { formatClockDate } from '../../utils/clockDate'
import { parseDateTime, toDateInput } from '../../utils/date'
import { addDays, classifyEntry, entriesByDay, entryHours, weekdayShort, formatHours } from '../../utils/hours'

const EDIT_WINDOW_MS = 7 * 86400000

export default {
  name: 'WeekTable',

  components: { AppIcon, HourTag, MissingDeparture },

  props: {
    monday: { type: Date, required: true },
    entries: { type: Array, required: true },
    now: { type: Date, required: true },
    userId: { type: [Number, String], default: null },
    // Whether the viewer may add or correct periods at all (role and scope).
    canRequest: { type: Boolean, default: false },
    canEdit: { type: Boolean, default: false },
  },

  emits: ['edit', 'create', 'completed', 'request'],

  data() {
    return { missingDeparture: null }
  },

  computed: {
    pendingDay() {
      return this.missingDeparture ? formatClockDate(this.missingDeparture.arrival.time).slice(0, 10) : null
    },
    rows() {
      return entriesByDay(this.entries, this.monday).map((entries, index) => {
        const date = addDays(this.monday, index)
        return {
          key: toDateInput(date),
          label: `${weekdayShort(date)} ${date.getDate()}`,
          editable: this.canEdit && date <= this.now && this.isEditable(addDays(date, 1)),
          entries: [...entries]
            .sort((a, b) => a.start.localeCompare(b.start))
            .map((entry) => ({
              ...entry,
              kind: classifyEntry(entry),
              hours: entryHours(entry),
              editable: this.canEdit && this.isEditable(parseDateTime(entry.end)),
            })),
        }
      })
    },
  },

  methods: {
    duration(value) { return formatHours(value) },
    isEditable(date) {
      if (!date) return false
      return this.now.getTime() - date.getTime() <= EDIT_WINDOW_MS
    },

    clock(value) {
      let date
      try { date = clockDate(value) } catch { return '' }
      return [date.getHours(), date.getMinutes()]
        .map((part) => String(part).padStart(2, '0')).join(':')
    },
  },
}
</script>

<style scoped>
.table-wrap {
  overflow-x: auto;
}

.week-table th[scope='row'] {
  font-weight: 700;
  white-space: nowrap;
}

.muted {
  color: var(--text-muted);
}

.state {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
}

.mobile-hours { display: none; }
.day-card { padding: 16px; }
.day-card header, .entry-summary { display: flex; align-items: center; justify-content: space-between; gap: 8px; flex-wrap: wrap; }
.mobile-entry { display: flex; flex-direction: column; gap: 12px; margin-top: 12px; }
.week-details > section { margin-top: 16px; }
@media (max-width: 760px) { .desktop-hours { display: none; } .mobile-hours { display: flex; flex-direction: column; gap: 10px; } }
</style>
