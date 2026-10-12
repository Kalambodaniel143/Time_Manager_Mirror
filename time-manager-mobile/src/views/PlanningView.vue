<template>
  <PageHeader title="Mon planning" :eyebrow="name" />
  <WeekTabs v-model="week" />
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!days.length" empty-text="Aucun planning publié pour cette semaine." @retry="load">
    <PlanningList :days="days" />
  </DataState>
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import DataState from '@/components/common/DataState.vue'
import WeekTabs from '@/components/planning/WeekTabs.vue'
import PlanningList from '@/components/planning/PlanningList.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { getPlanning } from '@/services/dataService.js'
import { daysOfWeek } from '@/ui/planningWeek.js'
import { displayName } from '@/ui/format.js'

export default {
  name: 'PlanningView',
  components: { PageHeader, DataState, WeekTabs, PlanningList },
  mixins: [loadable],
  data: () => ({ planning: [], week: 0 }),
  computed: {
    name: () => displayName(app.user),
    days() { return daysOfWeek(this.planning, this.week) },
  },
  created() { this.load() },
  methods: {
    async load() { this.planning = (await this.run(() => getPlanning())) ?? [] },
  },
}
</script>
