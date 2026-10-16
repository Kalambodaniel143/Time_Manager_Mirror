<template>
  <PageHeader :title="$t('Mes demandes')" :eyebrow="$t('Absences, corrections, échanges')" />
  <SegmentedTabs v-model="tab" :options="TABS" :label="$t('Type de demande')" />
  <AbsencesPanel v-if="tab === 'absences'" />
  <CorrectionsPanel v-else-if="tab === 'corrections'" :period="Number($route.query.period) || null" />
  <SwapsPanel v-else />
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import AbsencesPanel from '@/components/requests/AbsencesPanel.vue'
import CorrectionsPanel from '@/components/requests/CorrectionsPanel.vue'
import SwapsPanel from '@/components/requests/SwapsPanel.vue'

const TABS = [{ value: 'absences', label: t('Absences') }, { value: 'corrections', label: t('Corrections') }, { value: 'swaps', label: t('Échanges') }]

// Tout ce que je demande à mon responsable, au même endroit (comme sur le web).
export default {
  name: 'RequestsView',
  components: { PageHeader, SegmentedTabs, AbsencesPanel, CorrectionsPanel, SwapsPanel },
  data() { return { tab: TABS.some((t) => t.value === this.$route.query.tab) ? this.$route.query.tab : 'absences', TABS } },
}
</script>
