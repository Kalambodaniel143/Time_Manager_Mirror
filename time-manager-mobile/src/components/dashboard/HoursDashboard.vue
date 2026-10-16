<template>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt" @retry="load">
    <PeriodPicker v-model="period" />
    <StatTiles :tiles="tiles" hero compact />
    <BarChart :title="period.unit === 'day' ? $t('Heures par jour') : $t('Heures par semaine')" :bars="bars" />
    <section class="card">
      <h2>{{ $t('Détail · {0} garde{1}', [list.length, list.length > 1 ? 's' : '']) }}</h2>
      <p v-if="!list.length" class="muted">{{ $t('Aucune heure enregistrée sur cette période.') }}</p>
      <ul class="list flush">
        <li v-for="p in list.slice(0, shown)" :key="`${p.id}-${p.start}`">
          <div class="row"><strong>{{ longDate(p.start) }}</strong><span class="badge badge-ok">{{ $t('Confirmé') }}</span></div>
          <div class="row">
            <span>{{ hhmm(p.start) }} → {{ hhmm(p.end) }}</span>
            <span class="chip-soft" :class="`chip-${shiftType(p.start)}`">{{ SHIFT_LABELS[shiftType(p.start)] }} · {{ hours(p.end - p.start) }}</span>
          </div>
        </li>
      </ul>
      <button v-if="list.length > shown" type="button" class="btn-quiet" @click="shown += 10">{{ $t('Afficher plus') }}</button>
    </section>
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
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
  data: () => ({ periods: [], period: preset(0), shown: 6, SHIFT_LABELS }),
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
        { label: t('Total sur la période'), value: hours(s.total), hint: t('Jour {0} · Nuit {1} · moyennes par jour travaillé', [hours(s.total - s.night), hours(s.night)]) },
        { label: t('Par jour'), value: hours(s.perDay) },
        { label: t('Par semaine'), value: hours(s.perWeek) },
        { label: t('Nuit'), value: s.total ? `${Math.round((s.night / s.total) * 100)} %` : '—' },
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
