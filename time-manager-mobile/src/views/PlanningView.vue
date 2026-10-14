<template>
  <PageHeader :title="$t('Mon planning')" :eyebrow="name" />
  <RangePicker v-model="range" />
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!days.length" :empty-text="$t('Aucune garde publiée sur cette période.')" @retry="load">
    <PlanningList :days="days" />
  </DataState>
  <p class="small muted">{{ $t('Seules les versions publiées par votre responsable apparaissent ici. Pour échanger une garde, passez par Demandes.') }}</p>
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import DataState from '@/components/common/DataState.vue'
import RangePicker from '@/components/planning/RangePicker.vue'
import PlanningList from '@/components/planning/PlanningList.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { api, read } from '@/services/workforce.js'
import { shiftsOf, toDays } from '@/ui/plans.js'
import { weekRange } from '@/ui/weeks.js'
import { displayName } from '@/ui/format.js'

// Mes gardes publiées (GET /plans) sur la période choisie, lisibles hors ligne.
export default {
  name: 'PlanningView',
  components: { PageHeader, DataState, RangePicker, PlanningList },
  mixins: [loadable],
  data: () => ({ planning: [], range: weekRange(0) }),
  computed: {
    name: () => displayName(app.user),
    days() { return this.planning.filter((d) => d.date >= this.range.from && d.date <= this.range.to) },
  },
  watch: { range() { this.load() } },
  created() { this.load() },
  methods: {
    async load() {
      const { from, to } = this.range
      const plans = (await this.run(() => read(`plans:${from}:${to}`, () => api.getPlans(from, to)))) ?? []
      this.planning = toDays(shiftsOf(plans).filter((s) => s.user_id === app.user.id))
    },
  },
}
</script>
