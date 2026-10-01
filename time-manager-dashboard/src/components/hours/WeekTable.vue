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
            <td>—</td>
            <td>—</td>
            <td class="muted">Repos</td>
            <td>
              <button v-if="day.editable" class="btn btn-quiet btn-sm" type="button" @click="$emit('create', day.key)">Ajouter</button>
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
        <tr>
          <td colspan="5" class="marker-cell">
            <JonasMarker title="Ligne « Départ non pointé »" inline>Heure de départ à saisir + « Confirmer », depuis les pointages.</JonasMarker>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import HourTag from '../ui/HourTag.vue'
import JonasMarker from '../ui/JonasMarker.vue'
import { parseDateTime, toDateInput } from '../../utils/date'
import { addDays, classifyEntry, entriesByDay, entryHours, formatClock, weekdayShort } from '../../utils/hours'

const EDIT_WINDOW_MS = 7 * 86400000

export default {
  name: 'WeekTable',

  components: { AppIcon, HourTag, JonasMarker },

  props: {
    monday: { type: Date, required: true },
    entries: { type: Array, required: true },
    now: { type: Date, required: true },
  },

  emits: ['edit', 'create'],

  computed: {
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
      return formatClock(value)
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

.marker-cell {
  padding-top: 14px;
}
</style>
