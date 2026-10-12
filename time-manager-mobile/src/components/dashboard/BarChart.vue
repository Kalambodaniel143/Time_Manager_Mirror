<template>
  <figure class="card chart">
    <figcaption><strong>{{ title }}</strong></figcaption>
    <p class="chart-legend small">
      <span><i class="key key-jour" aria-hidden="true" />Jour</span>
      <span><i class="key key-nuit" aria-hidden="true" />Nuit</span>
      <span class="muted">{{ selected === null ? 'Touchez une barre' : detail(bars[selected]) }}</span>
    </p>
    <div class="chart-scroll">
      <div class="chart-plot" :style="{ minWidth: `${bars.length * 42}px` }">
        <span class="chart-max small muted">{{ hours(max) }}</span>
        <button v-for="(bar, i) in bars" :key="i" type="button" class="bar-slot" :class="{ selected: selected === i }"
          :aria-label="detail(bar)" @click="selected = selected === i ? null : i">
          <span class="bar-stack" :style="{ height: `${((bar.jour + bar.nuit) / max) * 100}%` }">
            <span v-if="bar.nuit" class="seg seg-nuit" :style="{ flexGrow: bar.nuit }" />
            <span v-if="bar.jour" class="seg seg-jour" :style="{ flexGrow: bar.jour }" />
          </span>
          <span class="bar-label">{{ bar.label }}</span>
        </button>
      </div>
    </div>
    <button type="button" class="btn-quiet" @click="table = !table">{{ table ? 'Masquer le tableau' : 'Voir en tableau' }}</button>
    <table v-if="table" class="data-table small">
      <thead><tr><th scope="col">Période</th><th scope="col">Jour</th><th scope="col">Nuit</th><th scope="col">Total</th></tr></thead>
      <tbody>
        <tr v-for="(bar, i) in bars" :key="i">
          <th scope="row">{{ bar.label }}</th><td>{{ hours(bar.jour) }}</td><td>{{ hours(bar.nuit) }}</td><td>{{ hours(bar.jour + bar.nuit) }}</td>
        </tr>
      </tbody>
    </table>
  </figure>
</template>

<script>
import { hours } from '@/ui/format.js'

// Barres empilées jour/nuit, sans bibliothèque. Toucher une barre affiche son détail ;
// le tableau donne les mêmes chiffres aux lecteurs d'écran (accessibilité).
export default {
  name: 'BarChart',
  props: { title: { type: String, required: true }, bars: { type: Array, required: true } },
  data: () => ({ selected: null, table: false }),
  computed: {
    max() { return Math.max(3_600_000, ...this.bars.map((b) => b.jour + b.nuit)) },
  },
  watch: { bars() { this.selected = null } },
  methods: {
    hours,
    detail: (bar) => `${bar.label} : ${hours(bar.jour + bar.nuit)} (jour ${hours(bar.jour)}, nuit ${hours(bar.nuit)})`,
  },
}
</script>
