<template>
  <BarChart v-if="members.length" :title="$t('Heures de l’organisation · moyenne par agent, cette semaine')" :bars="bars" />
</template>

<script>
import BarChart from '@/components/dashboard/BarChart.vue'
import { getMesHeures } from '@/services/dataService.js'
import { teamAggregate, toPeriods } from '@/ui/aggregate.js'
import { preset, toRange } from '@/ui/period.js'

// Heures de tous les membres sur la semaine en cours (jour / nuit par jour).
export default {
  name: 'OrgHours',
  components: { BarChart },
  props: { users: { type: Array, required: true } },
  data: () => ({ members: [] }),
  computed: {
    bars() {
      const { from, to } = toRange(preset(0))
      return teamAggregate(this.members, from, to, 'day')
    },
  },
  watch: { users: { immediate: true, handler() { this.load() } } },
  methods: {
    async load() {
      const results = await Promise.all(this.users.map((u) => getMesHeures(u.id).catch(() => null)))
      this.members = results.filter(Boolean).map((r) => toPeriods(r.data))
    },
  },
}
</script>
