<template>
  <PageHeader title="Planning d’équipe" eyebrow="Consultation par agent" />
  <label for="member">Afficher la semaine de</label>
  <select id="member" v-model="memberId" @change="loadPlanning">
    <option v-for="m in members" :key="m.id" :value="m.id">{{ displayName(m) }}</option>
  </select>
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
import { getPlanning, getTeams } from '@/services/dataService.js'
import { daysOfWeek } from '@/ui/planningWeek.js'
import { displayName } from '@/ui/format.js'

export default {
  name: 'TeamPlanningView',
  components: { PageHeader, DataState, WeekTabs, PlanningList },
  mixins: [loadable],
  data: () => ({ members: [], memberId: null, planning: [], week: 0 }),
  computed: {
    days() { return daysOfWeek(this.planning, this.week) },
  },
  created() { this.load() },
  methods: {
    displayName,
    async load() {
      const teams = (await this.run(() => getTeams())) ?? []
      const mine = (t) => t.manager?.id === app.user.id || app.user.role === 'administrator'
      this.members = teams.filter(mine).flatMap((t) => t.members)
      this.memberId ??= this.members[0]?.id
      if (this.memberId) await this.loadPlanning()
    },
    async loadPlanning() { this.planning = (await this.run(() => getPlanning(this.memberId))) ?? [] },
  },
}
</script>
