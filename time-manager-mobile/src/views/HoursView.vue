<template>
  <PageHeader title="Mes heures" :eyebrow="displayName(user)" />
  <SegmentedTabs v-model="tab" :options="TABS" />
  <HoursDashboard v-if="tab === 'dashboard'" :user-id="user.id" />
  <ClockHistory v-else :user-id="user.id" />
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import HoursDashboard from '@/components/dashboard/HoursDashboard.vue'
import ClockHistory from '@/components/history/ClockHistory.vue'
import { app } from '@/services/appState.js'
import { displayName } from '@/ui/format.js'

const TABS = [{ value: 'dashboard', label: 'Tableau de bord' }, { value: 'history', label: 'Historique' }]

// Mes heures = tableau de bord (graphiques) + historique des pointages.
export default {
  name: 'HoursView',
  components: { PageHeader, SegmentedTabs, HoursDashboard, ClockHistory },
  data: () => ({ tab: 'dashboard', TABS }),
  computed: { user: () => app.user },
  methods: { displayName },
}
</script>
