<template>
  <PageHeader :title="$t('Règles et droits')" :eyebrow="$t('Administration')" />
  <SegmentedTabs v-model="tab" :options="TABS" :label="$t('Rubrique')" />
  <DataState :loading="loading" :error="error" @retry="load">
    <RulesForm v-if="tab === 'rules' && rules" :initial="rules" />
    <TeamPermissions v-else-if="tab === 'rights'" :teams="teams" />
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import DataState from '@/components/common/DataState.vue'
import RulesForm from '@/components/admin/RulesForm.vue'
import TeamPermissions from '@/components/admin/TeamPermissions.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { act, api } from '@/services/workforce.js'
import { getTeams } from '@/services/dataService.js'

const TABS = [{ value: 'rules', label: t('Règles') }, { value: 'rights', label: t('Droits des équipes') }]

// Réglages de l'organisation (comme « Droits et règles » sur le web).
export default {
  name: 'RulesView',
  components: { PageHeader, SegmentedTabs, DataState, RulesForm, TeamPermissions },
  mixins: [loadable],
  data: () => ({ tab: 'rules', TABS, rules: null, teams: [] }),
  created() { this.load() },
  methods: {
    async load() {
      this.teams = (await getTeams().catch(() => null))?.data ?? []
      await this.run(async () => {
        if (!app.organization) throw new Error(t('Ce compte n’est rattaché à aucune organisation.'))
        const data = await act(() => api.getRules(app.organization.id))
        this.rules = data?.rules ?? data
        return { data: null, stale: false }
      })
    },
  },
}
</script>
