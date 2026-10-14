<template>
  <PageHeader :title="$t('Mes heures')" :eyebrow="displayName(user)" />
  <SegmentedTabs v-model="tab" :options="TABS" />
  <template v-if="tab === 'week'">
    <WeekHours :user-id="user.id" mine />
    <WeekNote />
  </template>
  <HoursDashboard v-else-if="tab === 'dashboard'" :user-id="user.id" />
  <ClockHistory v-else :user-id="user.id" />
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import HoursDashboard from '@/components/dashboard/HoursDashboard.vue'
import ClockHistory from '@/components/history/ClockHistory.vue'
import WeekNote from '@/components/hours/WeekNote.vue'
import WeekHours from '@/components/hours/WeekHours.vue'
import { app } from '@/services/appState.js'
import { displayName } from '@/ui/format.js'

const TABS = [{ value: 'week', label: t('Semaine') }, { value: 'dashboard', label: t('Graphiques') }, { value: 'history', label: t('Pointages') }]

// Mes heures = ma semaine jour par jour (+ note), graphiques sur une période, pointages.
export default {
  name: 'HoursView',
  components: { PageHeader, SegmentedTabs, HoursDashboard, ClockHistory, WeekNote, WeekHours },
  data: () => ({ tab: 'week', TABS }),
  computed: { user: () => app.user },
  methods: { displayName },
}
</script>
