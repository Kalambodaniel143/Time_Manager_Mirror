<template>
  <section class="week-head">
    <div>
      <p class="eyebrow">{{ $t('Semaine {0} · {1} – {2}', [weekNumber(monday), dayMonth(monday), dayMonth(sunday)]) }}</p>
      <p class="small muted">{{ $t('{0} garde{1}', [list.length, list.length > 1 ? 's' : '']) }}<template v-if="open"> {{ $t('· 1 service en cours') }}</template></p>
    </div>
    <div class="week-nav">
      <button type="button" class="icon-btn round" :aria-label="$t('Semaine précédente')" @click="offset--"><ChevronLeft :size="18" /></button>
      <button type="button" class="icon-btn round" :aria-label="$t('Semaine suivante')" :disabled="offset >= 0" @click="offset++"><ChevronRight :size="18" /></button>
    </div>
  </section>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt" @retry="load">
    <p class="card total-row"><span class="muted">{{ $t('Total confirmé ({0} jour{1})', [days, days > 1 ? 's' : '']) }}</span><strong>{{ hours(total) }}</strong></p>
    <p v-if="!list.length" class="card muted center">{{ $t('Aucune heure enregistrée cette semaine.') }}</p>
    <article v-for="p in list" :key="`${p.id}-${p.start}`" class="card shift-card">
      <p class="row"><strong>{{ dayName(p.start) }}</strong><span class="badge badge-ok">{{ $t('Confirmé') }}</span></p>
      <p class="row">
        <span class="shift-time">{{ hhmm(p.start) }} → {{ hhmm(p.end) }}</span>
        <span class="chip-soft" :class="`chip-${shiftType(p.start)}`">{{ SHIFT_LABELS[shiftType(p.start)] }} · {{ hours(p.end - p.start) }}</span>
      </p>
      <RouterLink v-if="mine" class="small fix-link" :to="{ name: 'requests', query: { tab: 'corrections', period: p.id } }">{{ $t('Demander une correction') }}</RouterLink>
    </article>
  </DataState>
</template>

<script>
import { locale } from '@/i18n/index.js'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import DataState from '@/components/common/DataState.vue'
import loadable from '@/ui/loadable.js'
import { getMesHeures } from '@/services/dataService.js'
import { toPeriods } from '@/ui/aggregate.js'
import { addDays, localDay, mondayOf, weekNumber } from '@/ui/dates.js'
import { dayMonth, hhmm, hours } from '@/ui/format.js'
import { SHIFT_LABELS, shiftType } from '@/ui/shifts.js'

// Mes heures d'une semaine, jour par jour (écran « Mes heures » de la maquette).
export default {
  name: 'WeekHours',
  components: { ChevronLeft, ChevronRight, DataState },
  mixins: [loadable],
  props: { userId: { type: Number, required: true }, mine: Boolean },
  data: () => ({ periods: [], offset: 0, SHIFT_LABELS }),
  computed: {
    monday() { return addDays(mondayOf(new Date()), 7 * this.offset) },
    sunday() { return addDays(this.monday, 6) },
    list() {
      return this.periods.filter((p) => p.end && p.start >= this.monday && p.start < addDays(this.monday, 7)).sort((a, b) => a.start - b.start)
    },
    open() { return this.periods.some((p) => !p.end) && this.offset === 0 },
    total() { return this.list.reduce((sum, p) => sum + (p.end - p.start), 0) },
    days() { return new Set(this.list.map((p) => localDay(p.start))).size },
  },
  created() { this.load() },
  methods: {
    hhmm, hours, dayMonth, weekNumber, shiftType,
    dayName: (date) => new Date(date).toLocaleDateString(locale(), { weekday: 'long', day: 'numeric' }).replace(/^./, (c) => c.toUpperCase()),
    async load() { this.periods = toPeriods(await this.run(() => getMesHeures(this.userId))) },
  },
}
</script>
