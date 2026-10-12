<template>
  <PageHeader :title="isAdmin ? 'Équipes' : 'Mon équipe'" eyebrow="Moyennes et heures des agents">
    <RouterLink v-if="isAdmin" class="button-link btn-outline" :to="{ name: 'teamsManage' }">Gérer les équipes</RouterLink>
  </PageHeader>
  <template v-if="teams.length > 1">
    <label for="team">Équipe</label>
    <select id="team" v-model="teamId" @change="loadMembers">
      <option v-for="t in teams" :key="t.id" :value="t.id">{{ t.name }}</option>
    </select>
  </template>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!members.length" empty-text="Aucun agent dans cette équipe." @retry="load">
    <PeriodPicker v-model="period" />
    <StatTiles :tiles="tiles" />
    <BarChart title="Moyenne par agent" :bars="bars" />
    <MemberList :members="members" :range="range" />
  </DataState>
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import DataState from '@/components/common/DataState.vue'
import PeriodPicker from '@/components/dashboard/PeriodPicker.vue'
import StatTiles from '@/components/dashboard/StatTiles.vue'
import BarChart from '@/components/dashboard/BarChart.vue'
import MemberList from '@/components/team/MemberList.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { getMesHeures, getTeams } from '@/services/dataService.js'
import { teamAggregate, teamStats, toPeriods } from '@/ui/aggregate.js'
import { preset, toRange } from '@/ui/period.js'
import { hours } from '@/ui/format.js'

// Tableau de bord d'équipe (responsable : ses équipes · administration : toutes).
export default {
  name: 'TeamView',
  components: { PageHeader, DataState, PeriodPicker, StatTiles, BarChart, MemberList },
  mixins: [loadable],
  data: () => ({ teams: [], teamId: null, members: [], period: preset(1) }),
  computed: {
    isAdmin: () => app.user.role === 'administrator',
    range() { return toRange(this.period) },
    withHours() { return this.members.filter((m) => m.periods).map((m) => m.periods) },
    bars() { return teamAggregate(this.withHours, this.range.from, this.range.to, this.period.unit) },
    tiles() {
      const s = teamStats(this.withHours, this.range.from, this.range.to)
      return [
        { label: 'Agents', value: String(this.members.length) },
        { label: 'Total équipe', value: hours(s.total) },
        { label: 'Moyenne / jour / agent', value: hours(s.perDay) },
        { label: 'Moyenne / semaine / agent', value: hours(s.perWeek) },
      ]
    },
  },
  created() { this.load() },
  methods: {
    async load() {
      // Les responsables ne voient les membres que des équipes qu'ils dirigent.
      this.teams = ((await this.run(() => getTeams())) ?? [])
        .filter((t) => this.isAdmin || t.manager?.id === app.user.id)
      this.teamId = this.teams.find((t) => t.id === this.teamId)?.id ?? this.teams[0]?.id ?? null
      await this.loadMembers()
    },
    async loadMembers() {
      this.loading = true
      const team = this.teams.find((t) => t.id === this.teamId)
      this.members = await Promise.all((team?.members ?? []).map(async (m) => {
        const result = await getMesHeures(m.id).catch(() => null)
        return { ...m, periods: result ? toPeriods(result.data) : null }
      }))
      this.loading = false
    },
  },
}
</script>
