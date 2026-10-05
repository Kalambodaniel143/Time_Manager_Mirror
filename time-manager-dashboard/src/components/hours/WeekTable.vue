<template>
  <div class="table-wrap">
    <table class="table week-table">
      <thead>
        <tr>
          <th scope="col">Jour</th>
          <th scope="col">Arrivée</th>
          <th scope="col">Départ</th>
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
            <td><HourTag :kind="entry.kind" :hours="entry.hours" short /></td>
            <td>
              <div class="state">
                <span class="pill pill-ok"><AppIcon name="check" />Enregistré</span>
                <button v-if="entry.editable" class="btn btn-quiet btn-sm" type="button" @click="$emit('edit', entry.id)">Corriger</button>
              </div>
            </td>
          </tr>
        </template>
        <MissingDeparture v-if="userId" :user-id="userId" :now="now" :week-start="monday" table-row @detected="missingDeparture = $event" @completed="$emit('completed')" @refreshed="$emit('completed')" />
      </tbody>
    </table>
  </div>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import HourTag from '../ui/HourTag.vue'
import MissingDeparture from '../MissingDeparture.vue'
import { formatClockDate } from '../../utils/clockDate'
import { parseDateTime, toDateInput } from '../../utils/date'
import { addDays, classifyEntry, entriesByDay, entryHours, weekdayShort } from '../../utils/hours'

const EDIT_WINDOW_MS = 7 * 86400000

export default {
  name: 'WeekTable',

  components: { AppIcon, HourTag, MissingDeparture },

  props: {
    monday: { type: Date, required: true },
    entries: { type: Array, required: true },
    now: { type: Date, required: true },
    userId: { type: [Number, String], default: null },
  },

  emits: ['edit', 'create', 'completed'],

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
          editable: date <= this.now && this.isEditable(addDays(date, 1)),
          entries: [...entries]
            .sort((a, b) => a.start.localeCompare(b.start))
            .map((entry) => ({
              ...entry,
              kind: classifyEntry(entry),
              hours: entryHours(entry),
              editable: this.isEditable(parseDateTime(entry.end)),
            })),
        }
      })
    },
  },

  methods: {
    isEditable(date) {
      if (!date) return false
      return this.now.getTime() - date.getTime() <= EDIT_WINDOW_MS
    },

    clock(value) {
      const date = parseDateTime(value)
      if (!date) return ''
      return [date.getHours(), date.getMinutes(), date.getSeconds()]
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

</style>
