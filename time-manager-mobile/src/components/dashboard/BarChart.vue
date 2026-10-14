<template>
  <figure class="card chart">
    <figcaption class="chart-head">
      <span><strong>{{ title }}</strong><br><span class="small muted">{{ $t('Total {0}', [hours(total)]) }}</span></span>
      <span class="chart-legend small">
        <span><i class="key key-jour" aria-hidden="true" />{{ $t('Jour') }}</span>
        <span><i class="key key-nuit" aria-hidden="true" />{{ $t('Nuit') }}</span>
      </span>
    </figcaption>
    <div class="chart-body">
      <div class="chart-axis small muted" aria-hidden="true">
        <span>{{ axis(top) }}</span><span>{{ axis(top / 2) }}</span><span>0</span>
      </div>
      <div class="chart-scroll">
        <div class="chart-plot" :class="{ focused: selected !== null }" :style="{ minWidth: `${bars.length * 34}px` }">
          <button v-for="(bar, i) in bars" :key="i" type="button" class="bar-slot" :class="{ selected: selected === i }"
            :aria-label="detail(bar)" @click="selected = selected === i ? null : i">
            <span v-if="selected === i" class="bar-value">{{ hours(bar.jour + bar.nuit) }}</span>
            <span class="bar-stack" :style="{ height: `${((bar.jour + bar.nuit) / top) * 100}%` }">
              <span v-if="bar.nuit" class="seg seg-nuit" :style="{ flexGrow: bar.nuit }" />
              <span v-if="bar.jour" class="seg seg-jour" :style="{ flexGrow: bar.jour }" />
            </span>
            <span class="bar-label">{{ bar.label }}</span>
          </button>
        </div>
      </div>
    </div>
    <p class="chart-detail small" aria-live="polite">{{ selected === null ? $t('Touchez une barre pour voir le détail.') : detail(bars[selected]) }}</p>
    <button type="button" class="btn-quiet small" @click="table = !table">{{ table ? $t('Masquer le tableau') : $t('Voir en tableau') }}</button>
    <table v-if="table" class="data-table small">
      <thead><tr><th scope="col">{{ $t('Période') }}</th><th scope="col">{{ $t('Jour') }}</th><th scope="col">{{ $t('Nuit') }}</th><th scope="col">{{ $t('Total') }}</th></tr></thead>
      <tbody>
        <tr v-for="(bar, i) in bars" :key="i">
          <th scope="row">{{ bar.label }}</th><td>{{ hours(bar.jour) }}</td><td>{{ hours(bar.nuit) }}</td><td>{{ hours(bar.jour + bar.nuit) }}</td>
        </tr>
      </tbody>
    </table>
  </figure>
</template>

<script>
import { t } from '@/i18n/index.js'
import { hours } from '@/ui/format.js'

const HOUR = 3_600_000
const STEPS = [1, 2, 4, 6, 8, 10, 12, 16, 24, 40, 48, 60, 80, 120, 160, 240]

// Barres empilées jour / nuit, sans bibliothèque : échelle arrondie, détail au toucher,
// tableau équivalent pour les lecteurs d'écran.
export default {
  name: 'BarChart',
  props: { title: { type: String, required: true }, bars: { type: Array, required: true } },
  data: () => ({ selected: null, table: false }),
  computed: {
    total() { return this.bars.reduce((sum, b) => sum + b.jour + b.nuit, 0) },
    // Haut de l'échelle : valeur « ronde » juste au-dessus de la plus grande barre.
    top() {
      const max = Math.max(...this.bars.map((b) => b.jour + b.nuit), 0) / HOUR
      return (STEPS.find((s) => s >= max) ?? Math.ceil(max / 40) * 40) * HOUR
    },
  },
  watch: { bars() { this.selected = null } },
  methods: {
    hours,
    axis: (ms) => `${Math.round((ms / HOUR) * 10) / 10} h`,
    detail: (bar) => t('{0} : {1} · jour {2} · nuit {3}', [bar.label, hours(bar.jour + bar.nuit), hours(bar.jour), hours(bar.nuit)]),
  },
}
</script>
