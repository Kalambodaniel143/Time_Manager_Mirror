<template>
  <section class="card chart-manager">
    <header class="card-header">
      <div>
        <h3 class="card-title">Tendances</h3>
        <p class="card-subtitle">Trois regards sur votre temps de travail</p>
      </div>
      <span class="mockup-tag">Maquette · Jonas</span>
    </header>

    <div class="card-body">
      <div class="segmented" role="tablist" aria-label="Type de graphique">
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
          {{ chart.label }}
        </button>
      </div>

      <div class="chart-placeholder" role="img" :aria-label="`Emplacement du graphique ${activeLabel}`">
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
          <circle
            cx="70"
            cy="70"
            r="50"
            fill="none"
            stroke="var(--series-3)"
            stroke-width="20"
            stroke-dasharray="210 314"
            transform="rotate(-90 70 70)"
          />
        </svg>
      </div>
    </div>
  </section>
</template>

<script>
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
      barHeights: [64, 92, 48, 108, 76, 88, 56],
      linePoints: '10,110 60,72 110,88 160,40 210,58 260,28 310,44',
    }
  },

  computed: {
    activeLabel() {
      const chart = this.charts.find((item) => item.key === this.activeChart)
      return chart ? chart.label : ''
    },
  },
}
</script>

<style scoped>
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
