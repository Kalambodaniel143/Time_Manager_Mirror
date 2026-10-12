<template>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt" @retry="load">
    <PeriodPicker v-model="period" />
    <StatTiles :tiles="tiles" />
    <BarChart :title="period.unit === 'day' ? 'Heures par jour' : 'Heures par semaine'" :bars="bars" />
    <section class="card">
      <h2>Détail · {{ list.length }} garde{{ list.length > 1 ? 's' : '' }}</h2>
      <p v-if="!list.length" class="muted">Aucune heure enregistrée sur cette période.</p>
      <ul class="list flush">
        <li v-for="p in list.slice(0, shown)" :key="`${p.id}-${p.start}`">
          <div class="row"><strong>{{ longDate(p.start) }}</strong><span class="badge badge-ok">Confirmé</span></div>
          <div class="row">
            <span>{{ hhmm(p.start) }} → {{ hhmm(p.end) }}</span>
            <span class="tag" :class="`tag-${shiftType(p.start)}`">{{ SHIFT_LABELS[shiftType(p.start)] }} · {{ hours(p.end - p.start) }}</span>
          </div>
        </li>
      </ul>
      <button v-if="list.length > shown" type="button" class="btn-quiet" @click="shown += 15">Afficher plus</button>
    </section>
  </DataState>
</template>

<script>
import DataState from '@/components/common/DataState.vue'
import PeriodPicker from './PeriodPicker.vue'
import StatTiles from './StatTiles.vue'
import BarChart from './BarChart.vue'
import loadable from '@/ui/loadable.js'
import { getMesHeures } from '@/services/dataService.js'
import { aggregate, stats, toPeriods } from '@/ui/aggregate.js'
import { preset, toRange } from '@/ui/period.js'
import { addDays } from '@/ui/dates.js'
import { hhmm, hours, longDate } from '@/ui/format.js'
import { SHIFT_LABELS, shiftType } from '@/ui/shifts.js'

// Tableau de bord d'un agent : heures par jour ou par semaine sur une période.
export default {
  name: 'HoursDashboard',
  components: { DataState, PeriodPicker, StatTiles, BarChart },
  mixins: [loadable],
  props: { userId: { type: Number, required: true } },
  data: () => ({ periods: [], period: preset(0), shown: 15, SHIFT_LABELS }),
  computed: {
    range() { return toRange(this.period) },
    bars() { return aggregate(this.periods, this.range.from, this.range.to, this.period.unit) },
    list() {
      const { from, to } = this.range
      return this.periods.filter((p) => p.start >= from && p.start < addDays(to, 1)).sort((a, b) => b.start - a.start)
    },
    tiles() {
      const s = stats(this.periods, this.range.from, this.range.to)
      return [
        { label: 'Total', value: hours(s.total) },
        { label: 'Moyenne / jour travaillé', value: hours(s.perDay) },
        { label: 'Moyenne / semaine', value: hours(s.perWeek) },
        { label: 'Part de nuit', value: s.total ? `${Math.round((s.night / s.total) * 100)} %` : '—' },
      ]
    },
  },
  created() { this.load() },
  methods: {
    hhmm, hours, longDate, shiftType,
    async load() { this.periods = toPeriods(await this.run(() => getMesHeures(this.userId))) },
  },
}
</script>
