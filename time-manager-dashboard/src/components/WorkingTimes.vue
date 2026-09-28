<template>
  <section class="card working-times">
    <header class="card-header">
      <div>
        <h3 class="card-title">Mes heures</h3>
        <p class="card-subtitle">
          <template v-if="loading">On rassemble vos périodes…</template>
          <template v-else-if="workingTimes.length">
            {{ workingTimes.length }} période{{ workingTimes.length > 1 ? 's' : '' }} ·
            <strong class="num">{{ totalLabel }}</strong> au total
          </template>
          <template v-else>Aucune période sur cette plage</template>
        </p>
      </div>
      <button class="btn btn-primary" type="button" @click="openCreate">
        <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M8 3.5v9M3.5 8h9" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" /></svg>
        Nouvelle période
      </button>
    </header>

    <div class="toolbar">
      <div class="ranges" role="group" aria-label="Plage rapide">
        <button
          v-for="range in ranges"
          :key="range.key"
          class="chip"
          :class="{ 'is-active': activeRange === range.key }"
          type="button"
          @click="applyRange(range.key)"
        >
          {{ range.label }}
        </button>
      </div>
      <div class="dates">
        <label class="date-field">
          <span>Du</span>
          <input v-model="startFilter" class="input input-compact" type="date" :max="endFilter || undefined" />
        </label>
        <label class="date-field">
          <span>au</span>
          <input v-model="endFilter" class="input input-compact" type="date" :min="startFilter || undefined" />
        </label>
      </div>
    </div>

    <div v-if="loading" class="list">
      <div v-for="n in 5" :key="n" class="skeleton skeleton-row"></div>
    </div>

    <div v-else-if="error" class="empty-state">
      <p class="empty-state-title">Impossible de charger vos heures</p>
      <p class="empty-state-text">{{ error }}</p>
      <button class="btn btn-ghost" type="button" @click="getWorkingTimes">Réessayer</button>
    </div>

    <div v-else-if="workingTimes.length === 0" class="empty-state">
      <svg viewBox="0 0 120 96" aria-hidden="true">
        <rect x="14" y="16" width="72" height="64" rx="10" fill="var(--surface-muted)" stroke="var(--border-strong)" stroke-width="2" />
        <path d="M14 34h72" stroke="var(--border-strong)" stroke-width="2" />
        <path d="M32 10v12M68 10v12" stroke="var(--border-strong)" stroke-width="3" stroke-linecap="round" />
        <circle cx="84" cy="64" r="22" fill="var(--accent-soft)" stroke="var(--accent)" stroke-width="2.5" />
        <path d="M84 52v12l8 5" fill="none" stroke="var(--accent)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
        <path d="M28 48h14M28 60h22" stroke="var(--border-strong)" stroke-width="3" stroke-linecap="round" />
      </svg>
      <p class="empty-state-title">Rien par ici pour l'instant</p>
      <p class="empty-state-text">
        {{ hasFilters ? 'Aucune période sur ces dates. Élargissez la plage, ou ajoutez-en une.' : 'Ajoutez votre première période de travail, elle apparaîtra ici.' }}
      </p>
      <button class="btn btn-primary" type="button" @click="openCreate">Ajouter une période</button>
    </div>

    <div v-else class="list">
      <div class="scale" aria-hidden="true">
        <span></span>
        <div class="scale-track">
          <span v-for="tick in ticks" :key="tick" class="scale-tick" :style="{ left: `${tickPosition(tick)}%` }">{{ tick }}h</span>
        </div>
        <span></span>
        <span></span>
      </div>

      <section v-for="week in weeks" :key="week.key" class="week">
        <header class="week-header">
          <h4 class="week-title serif">{{ week.label }}</h4>
          <span class="week-total num">{{ week.totalLabel }}</span>
        </header>

        <button
          v-for="entry in week.entries"
          :key="entry.id"
          class="row"
          type="button"
          :aria-label="`Modifier la période du ${longDate(entry.start)}, de ${time(entry.start)} à ${time(entry.end)}`"
          @click="openEdit(entry)"
        >
          <span class="row-day">
            <span class="row-weekday">{{ weekday(entry.start) }}</span>
            <span class="row-date">{{ dayMonth(entry.start) }}</span>
          </span>

          <span class="row-track" :title="`${time(entry.start)} → ${time(entry.end)}`">
            <span class="row-noon"></span>
            <span class="row-bar" :style="barStyle(entry)"></span>
          </span>

          <span class="row-hours num">{{ time(entry.start) }} – {{ time(entry.end) }}</span>

          <span class="row-duration num">{{ duration(entry) }}</span>

          <svg class="row-edit" viewBox="0 0 16 16" aria-hidden="true">
            <path d="M10.5 2.5l3 3L6 13H3v-3z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" />
          </svg>
        </button>
      </section>
    </div>

    <WorkingTime
      :user-id="userId"
      :working-time="selected"
      :open="dialogOpen"
      @close="closeDialog"
      @saved="handleChange"
      @deleted="handleChange"
    />
  </section>
</template>

<script>
import WorkingTime from './WorkingTime.vue'
import { getWorkingTimes } from '../services/workingTimeService'
import {
  durationInHours,
  formatDayMonth,
  formatDuration,
  formatLongDate,
  formatTimeLabel,
  formatWeekday,
  hourOfDay,
  isSameDay,
  startOfWeek,
  toDateInput,
} from '../utils/date'

const DAY_START = 6
const DAY_END = 22

function shiftDate(date, days) {
  const copy = new Date(date)
  copy.setDate(copy.getDate() + days)
  return copy
}

export default {
  name: 'WorkingTimes',

  components: { WorkingTime },

  props: {
    userID: { type: [Number, String], required: true },
  },

  emits: ['changed'],

  data() {
    return {
      userId: Number(this.userID),
      workingTimes: [],
      loading: false,
      error: '',
      startFilter: '',
      endFilter: '',
      dialogOpen: false,
      selected: null,
      ticks: [8, 12, 16, 20],
      ranges: [
        { key: 'week', label: 'Cette semaine' },
        { key: 'month', label: 'Ce mois-ci' },
        { key: 'last30', label: '30 derniers jours' },
        { key: 'all', label: 'Tout' },
      ],
    }
  },

  computed: {
    hasFilters() {
      return Boolean(this.startFilter || this.endFilter)
    },

    filters() {
      const filters = {}

      if (this.startFilter) filters.start = `${this.startFilter} 00:00:00`
      if (this.endFilter) filters.end = `${this.endFilter} 23:59:59`

      return filters
    },

    totalLabel() {
      const total = this.workingTimes.reduce(
        (sum, entry) => sum + durationInHours(entry.start, entry.end),
        0,
      )
      return formatDuration(total)
    },

    rangeValues() {
      const today = new Date()
      const monday = startOfWeek(today)

      return {
        week: { start: toDateInput(monday), end: toDateInput(shiftDate(monday, 6)) },
        month: {
          start: toDateInput(new Date(today.getFullYear(), today.getMonth(), 1)),
          end: toDateInput(new Date(today.getFullYear(), today.getMonth() + 1, 0)),
        },
        last30: { start: toDateInput(shiftDate(today, -29)), end: toDateInput(today) },
        all: { start: '', end: '' },
      }
    },

    activeRange() {
      const match = Object.entries(this.rangeValues).find(
        ([, range]) => range.start === this.startFilter && range.end === this.endFilter,
      )
      return match ? match[0] : null
    },

    weeks() {
      const thisWeek = toDateInput(startOfWeek(new Date()))
      const lastWeek = toDateInput(shiftDate(startOfWeek(new Date()), -7))
      const groups = new Map()

      this.workingTimes.forEach((entry) => {
        const monday = startOfWeek(entry.start)
        const key = toDateInput(monday)

        if (!groups.has(key)) groups.set(key, { key, monday, entries: [], total: 0 })

        const group = groups.get(key)
        group.entries.push(entry)
        group.total += durationInHours(entry.start, entry.end)
      })

      return [...groups.values()]
        .sort((a, b) => b.key.localeCompare(a.key))
        .map((group) => ({
          key: group.key,
          label:
            group.key === thisWeek
              ? 'Cette semaine'
              : group.key === lastWeek
                ? 'Semaine dernière'
                : `Semaine du ${group.monday.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' })}`,
          totalLabel: formatDuration(group.total),
          entries: [...group.entries].sort((a, b) => a.start.localeCompare(b.start)),
        }))
    },
  },

  watch: {
    userID(value) {
      this.userId = Number(value)
    },

    userId: {
      immediate: true,
      handler() {
        this.getWorkingTimes()
      },
    },

    filters() {
      this.getWorkingTimes()
    },
  },

  methods: {
    async getWorkingTimes() {
      this.loading = true
      this.error = ''

      try {
        this.workingTimes = (await getWorkingTimes(this.userId, this.filters)) || []
      } catch (error) {
        this.error = error.message
        this.workingTimes = []
      } finally {
        this.loading = false
      }
    },

    applyRange(key) {
      const range = this.rangeValues[key]
      this.startFilter = range.start
      this.endFilter = range.end
    },

    tickPosition(hour) {
      return ((hour - DAY_START) / (DAY_END - DAY_START)) * 100
    },

    barStyle(entry) {
      const span = DAY_END - DAY_START
      const start = hourOfDay(entry.start)
      const end = isSameDay(entry.start, entry.end) ? hourOfDay(entry.end) : 24
      const left = Math.min(Math.max((start - DAY_START) / span, 0), 1)
      const right = Math.min(Math.max((end - DAY_START) / span, 0), 1)

      return {
        left: `${left * 100}%`,
        width: `${Math.max(right - left, 0.015) * 100}%`,
      }
    },

    weekday(value) {
      return formatWeekday(value)
    },

    dayMonth(value) {
      return formatDayMonth(value)
    },

    longDate(value) {
      return formatLongDate(value)
    },

    time(value) {
      return formatTimeLabel(value)
    },

    duration(entry) {
      return formatDuration(durationInHours(entry.start, entry.end))
    },

    openCreate() {
      this.selected = null
      this.dialogOpen = true
    },

    openEdit(entry) {
      this.selected = { ...entry }
      this.dialogOpen = true
    },

    closeDialog() {
      this.dialogOpen = false
      this.selected = null
    },

    async handleChange() {
      await this.getWorkingTimes()
      this.$emit('changed')
    },
  },
}
</script>

<style scoped>
.toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px 16px;
  padding: 0 24px 18px;
}

.ranges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.dates {
  display: flex;
  gap: 10px;
}

.date-field {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12.5px;
  color: var(--text-muted);
}

.input-compact {
  width: auto;
  padding: 6px 10px;
  font-size: 13px;
}

.list {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 4px 16px 18px;
  border-top: 1px solid var(--border);
}

.skeleton-row {
  height: 52px;
  margin-top: 8px;
}

.scale,
.row {
  display: grid;
  grid-template-columns: 76px minmax(0, 1fr) 170px 125px 20px;
  align-items: center;
  gap: 16px;
}

.scale {
  padding: 14px 12px 2px;
}

.scale-track {
  position: relative;
  height: 16px;
}

.scale-tick {
  position: absolute;
  transform: translateX(-50%);
  font-size: 11px;
  color: var(--text-subtle);
  font-variant-numeric: tabular-nums;
}

.week {
  display: flex;
  flex-direction: column;
}

.week-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  padding: 16px 12px 8px;
}

.week-title {
  font-size: 16px;
}

.week-total {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-muted);
}

.row {
  width: 100%;
  padding: 11px 12px;
  background: transparent;
  border: none;
  border-radius: var(--radius);
  text-align: left;
  transition: background-color 0.14s ease;
}

.row:hover {
  background: var(--surface-hover);
}

.row-day {
  display: flex;
  flex-direction: column;
  line-height: 1.25;
}

.row-weekday {
  font-weight: 600;
}

.row-date {
  font-size: 12.5px;
  color: var(--text-muted);
}

.row-track {
  position: relative;
  height: 10px;
  background: var(--track);
  border-radius: 999px;
}

.row-noon {
  position: absolute;
  top: -3px;
  bottom: -3px;
  left: 37.5%;
  width: 1px;
  background: var(--border-strong);
}

.row-bar {
  position: absolute;
  top: 0;
  bottom: 0;
  background: var(--accent);
  border-radius: 999px;
  transition: filter 0.14s ease;
}

.row:hover .row-bar {
  filter: brightness(1.08);
}

.row-hours {
  font-size: 13.5px;
  color: var(--text-muted);
}

.row-duration {
  font-weight: 600;
  text-align: right;
}

.row-edit {
  width: 16px;
  height: 16px;
  color: var(--text-subtle);
  opacity: 0;
  transition: opacity 0.14s ease;
}

.row:hover .row-edit,
.row:focus-visible .row-edit {
  opacity: 1;
}

@media (max-width: 720px) {
  .scale {
    display: none;
  }

  .row {
    grid-template-columns: 64px minmax(0, 1fr) auto;
    gap: 12px;
  }

  .row-track,
  .row-edit {
    display: none;
  }

  .toolbar {
    flex-direction: column;
    align-items: stretch;
  }

  .dates {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .date-field {
    flex-direction: column;
    align-items: stretch;
    gap: 4px;
    min-width: 0;
  }

  .input-compact {
    width: 100%;
    min-width: 0;
  }
}
@media (max-width: 560px) {
  .row {
    grid-template-columns: 64px minmax(0, 1fr);
    gap: 4px 12px;
  }

  .row-day {
    grid-row: span 2;
  }

  .row-duration {
    grid-column: 2;
    text-align: left;
  }
}
</style>
