<template>
  <section class="card chart-manager">
    <header class="card-header">
      <div>
        <h3 class="card-title">{{ $t("Tendances") }}</h3>
        <p class="card-subtitle">{{ $t("Heures enregistrées cette semaine · jours en UTC") }}</p>
      </div>
      <button class="btn btn-outline btn-sm" type="button" :disabled="loading" @click="load">{{ $t("Actualiser") }}</button>
    </header>

    <p v-if="loading" class="card-body" role="status">{{ $t("Chargement des heures…") }}</p>
    <p v-else-if="error" class="card-body field-error" role="alert">{{ $t(error) }}</p>
    <div v-else class="card-body">
      <div class="segmented" role="tablist" :aria-label="$t(&quot;Type de graphique&quot;)">
        <button
          v-for="chart in charts"
          :key="chart.key"
          class="segment"
          :class="{ active: chart.key === activeChart }"
          type="button"
          role="tab"
          :aria-selected="chart.key === activeChart"
          @click="activeChart = chart.key"
        >
          {{ $t(chart.label) }}
        </button>
      </div>

      <p class="card-subtitle">{{ hours(total) }} {{ $t("enregistrées") }}</p>
      <div class="chart-placeholder" role="img" :aria-label="`${$t(activeLabel)} : ${days.map(day => `${label(day.date)} ${hours(day.hours)}`).join(', ')}`">
        <svg v-if="activeChart === 'bar'" viewBox="0 0 320 140" preserveAspectRatio="none">
          <rect
            v-for="(height, index) in barHeights"
            :key="index"
            :x="index * 44 + 14"
            :y="130 - height"
            width="26"
            :height="height"
            rx="4"
            fill="var(--series-1)"
          />
        </svg>

        <svg v-else-if="activeChart === 'line'" viewBox="0 0 320 140" preserveAspectRatio="none">
          <polyline
            :points="linePoints"
            fill="none"
            stroke="var(--series-2)"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            vector-effect="non-scaling-stroke"
          />
        </svg>

        <svg v-else viewBox="0 0 140 140">
          <circle cx="70" cy="70" r="50" fill="none" stroke="var(--track)" stroke-width="20" />
          <circle v-for="(slice, index) in slices" :key="index"
            cx="70"
            cy="70"
            r="50"
            fill="none"
            :stroke="['var(--series-1)', 'var(--series-2)', 'var(--series-3)'][index % 3]"
            stroke-width="20"
            :stroke-dasharray="`${slice.length} ${circumference}`"
            :stroke-dashoffset="-slice.offset"
            transform="rotate(-90 70 70)"
          />
        </svg>
      </div>
      <ul class="daily-values"><li v-for="day in days" :key="day.key">{{ $t(label(day.date)) }} : {{ hours(day.hours) }}</li></ul>
    </div>
  </section>
</template>

<script>
import { intlLocale } from '../utils/i18n.js'

import { getWorkingTimes } from '../services/workingTimeService'
import { dailyHours } from '../services/reportService'
import { formatHours, mondayOf } from '../utils/hours'

export default {
  name: 'ChartManager',

  props: {
    userId: { type: [Number, String], required: true },
  },

  data() {
    return {
      activeChart: 'bar',
      charts: [
        { key: 'bar', label: 'Par jour' },
        { key: 'line', label: 'Évolution' },
        { key: 'pie', label: 'Répartition' },
      ],
      entries: [], loading: false, error: '', version: 0, monday: mondayOf(), circumference: 2 * Math.PI * 50,
    }
  },

  computed: {
    days() { return dailyHours(this.entries, this.monday) },
    total() { return this.days.reduce((sum, day) => sum + day.hours, 0) },
    barHeights() { const max = Math.max(1, ...this.days.map(day => day.hours)); return this.days.map(day => day.hours / max * 120) },
    linePoints() { return this.barHeights.map((height, index) => `${index * 44 + 14},${130 - height}`).join(' ') },
    slices() { let offset = 0; return this.days.map(day => { const length = this.total ? day.hours / this.total * this.circumference : 0; const slice = { length, offset }; offset += length; return slice }) },
    activeLabel() {
      const chart = this.charts.find((item) => item.key === this.activeChart)
      return chart ? chart.label : ''
    },
  },
  watch: { userId: { immediate: true, handler() { this.load() } } },
  beforeUnmount() { this.version += 1 },
  methods: {
    hours: formatHours,
    label(date) { return date.toLocaleDateString(intlLocale(), { weekday: 'short', day: 'numeric' }) },
    async load() {
      const version = ++this.version; this.loading = true; this.error = ''; this.entries = []; this.monday = mondayOf()
      try { const entries = await getWorkingTimes(this.userId); if (!Array.isArray(entries)) throw new Error('Liste des heures invalide.'); dailyHours(entries, this.monday); if (version === this.version) this.entries = entries }
      catch (error) { if (version === this.version) this.error = error.message }
      finally { if (version === this.version) this.loading = false }
    },
  },
}
</script>

<style scoped>
.daily-values { display: flex; gap: 14px; flex-wrap: wrap; padding: 0; list-style: none; font-size: 13px; }
.chart-manager {
  --series-1: #2a78d6;
  --series-2: #eb6834;
  --series-3: #1baf7a;
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme='light']) .chart-manager {
    --series-1: #3987e5;
    --series-2: #d95926;
    --series-3: #199e70;
  }
}

:root[data-theme='dark'] .chart-manager {
  --series-1: #3987e5;
  --series-2: #d95926;
  --series-3: #199e70;
}

.segmented {
  display: inline-flex;
  gap: 2px;
  margin-bottom: 16px;
  padding: 3px;
  background: var(--surface-muted);
  border: 1px solid var(--border);
  border-radius: 999px;
}

.segment {
  padding: 6px 14px;
  background: transparent;
  border: none;
  border-radius: 999px;
  font-size: 12.5px;
  font-weight: 500;
  color: var(--text-muted);
  transition: background-color 0.15s ease, color 0.15s ease, box-shadow 0.15s ease;
}

.segment:hover {
  color: var(--text);
}

.segment.active {
  background: var(--surface);
  box-shadow: var(--shadow-sm);
  color: var(--text);
}

.chart-placeholder {
  display: grid;
  place-items: center;
  min-height: 200px;
  padding: 20px;
  background: var(--surface-muted);
  border-radius: var(--radius);
}

.chart-placeholder svg {
  width: 100%;
  max-width: 360px;
  height: 160px;
}
</style>
