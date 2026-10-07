<template>
  <div>
  <div class="grid-wrap card desktop-plan">
    <table class="plan">
      <thead>
        <tr>
          <th scope="col" class="agent-col">Agent</th>
          <th v-for="day in columns" :key="day.key" scope="col" class="day-col" :class="{ 'is-weekend': day.weekend }">
            <span class="day-name">{{ day.name }}</span>
            <span class="day-number serif num">{{ day.number }}</span>
          </th>
          <th scope="col" class="run-col">Nuits d’affilée</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.username">
          <th scope="row" class="agent">
            <span class="agent-name">{{ row.name }}</span>
            <span class="agent-unit">{{ row.unit }}</span>
          </th>
          <td v-for="(kind, index) in row.shifts" :key="index">
            <button
              class="cell"
              :class="[`cell-${kind}`, { 'is-flagged': isFlagged(row, index) }]"
              type="button"
              :title="`${row.short} · ${columns[index].label} : ${labels[kind]} (cliquer pour changer)`"
              @click="$emit('cycle', row.username, index + offset)"
            >
              {{ labels[kind] }}
            </button>
          </td>
          <td class="run">
            <span v-if="row.run.length > maxNights" class="pill pill-danger"><AppIcon name="alert" />{{ nightsLabel(row.run.length) }}</span>
            <span v-else class="pill pill-ok"><AppIcon name="check" />{{ nightsLabel(row.run.length) }}</span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
  <div v-if="mobileRow" class="mobile-plan card"><article v-for="(kind, index) in mobileRow.shifts" :key="index"><strong>{{ columns[index].label }}</strong><button class="cell" :class="`cell-${kind}`" type="button" :aria-label="`${columns[index].label} : ${labels[kind]}, modifier`" @click="$emit('cycle', mobileRow.username, index + offset)">{{ labels[kind] }}</button></article></div>
  </div>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import { toDateInput } from '../../utils/date'
import { weekdayUpper } from '../../utils/hours'

const LABELS = { day: 'Jour', night: 'Nuit', oncall: 'Astreinte', leave: 'Congé', rest: 'Repos' }

export default {
  name: 'PlanGrid',

  components: { AppIcon },

  props: {
    offset: { type: Number, default: 0 },
    selectedAgent: { type: String, default: '' },
    days: { type: Array, required: true },
    rows: { type: Array, required: true },
    maxNights: { type: Number, required: true },
  },

  emits: ['cycle'],

  data() {
    return { labels: LABELS }
  },

  computed: {
    mobileRow() { return this.rows.find(row => row.username === this.selectedAgent) || this.rows[0] },
    columns() {
      return this.days.map((date) => ({
        key: toDateInput(date),
        name: `${weekdayUpper(date).replace('.', '')}.`,
        number: date.getDate(),
        label: date.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' }),
        weekend: date.getDay() === 0 || date.getDay() === 6,
      }))
    },
  },

  methods: {
    isFlagged(row, index) {
      const { run } = row
      return run.length > this.maxNights && index + this.offset >= run.start && index + this.offset < run.start + run.length
    },

    nightsLabel(count) {
      return `${count} nuit${count > 1 ? 's' : ''}`
    },
  },
}
</script>

<style scoped>
.grid-wrap {
  padding: 12px 20px 8px;
  overflow-x: auto;
}

.plan {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
}

.plan th,
.plan td {
  padding: 4px 2.5px;
  border-bottom: 1px solid var(--border);
}

.plan thead th {
  padding-bottom: 10px;
  border-bottom: 2px solid var(--brand-soft);
  font-weight: 400;
}

.agent-col,
.run-col {
  font-size: 14.5px;
  color: var(--text-muted);
  text-align: left;
}

.run-col {
  text-align: right;
}

.day-col {
  min-width: 52px;
  text-align: center;
}

.day-name {
  display: block;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.04em;
}

.day-number {
  display: block;
  font-size: 22px;
}

.is-weekend .day-number {
  color: var(--title);
}

.agent {
  min-width: 170px;
  padding-right: 12px;
  text-align: left;
}

.agent-name {
  display: block;
  font-size: 16px;
  font-weight: 700;
}

.agent-unit {
  display: block;
  font-size: 14px;
  font-weight: 400;
  color: var(--text-muted);
}

.cell {
  display: grid;
  place-items: center;
  width: 100%;
  min-width: 50px;
  height: 46px;
  border: 1.5px solid transparent;
  border-radius: 2px;
  font-size: 12.5px;
  font-weight: 700;
}

.cell-day { background: var(--day-bg); color: var(--day-fg); border-color: var(--day-bd); }
.cell-night { background: var(--night-bg); color: var(--night-fg); border-color: var(--night-bd); }
.cell-oncall { background: var(--oncall-bg); color: var(--oncall-fg); border-color: var(--oncall-bd); }
.cell-leave { background: var(--leave-bg); color: var(--leave-fg); border-color: var(--leave-bd); }

.cell-rest {
  background: transparent;
  border: 1px dashed var(--rest-bd);
  color: var(--text-muted);
  font-weight: 400;
}

.cell.is-flagged {
  outline: 2px solid var(--banner-danger-bg);
  outline-offset: 1px;
}

.run {
  padding-left: 16px;
  text-align: right;
}
.mobile-plan { display: none; }
@media (max-width: 760px) { .desktop-plan { display: none; } .mobile-plan { display: block; padding: 8px 16px; } .mobile-plan article { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 12px 0; border-bottom: 1px solid var(--border); } .mobile-plan strong { font-size: 12px; } .mobile-plan .cell { width: 100px; border-radius: 6px; } }
</style>
