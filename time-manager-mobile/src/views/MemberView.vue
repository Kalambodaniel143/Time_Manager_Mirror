<template>
  <PageHeader :title="user ? displayName(user) : $t('Agent')" :eyebrow="user ? `${ROLE_LABELS[user.role]} · ${user.email}` : ''">
    <button type="button" class="btn-quiet back-link" @click="$router.back()">{{ $t('‹ Retour') }}</button>
  </PageHeader>
  <p v-if="error" class="notice-danger">{{ error }}</p>
  <UserAdminCard v-if="isAdmin && user && user.id !== me.id" :user="user" @changed="load" @deleted="$router.replace({ name: 'organization' })" />
  <SegmentedTabs v-model="tab" :options="TABS" />
  <HoursDashboard v-if="tab === 'dashboard'" :key="version" :user-id="userId" />
  <ClockHistory v-else-if="tab === 'history'" :user-id="userId" />
  <PeriodEditor v-else :user-id="userId" @changed="version++" />
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import HoursDashboard from '@/components/dashboard/HoursDashboard.vue'
import ClockHistory from '@/components/history/ClockHistory.vue'
import UserAdminCard from '@/components/admin/UserAdminCard.vue'
import PeriodEditor from '@/components/hours/PeriodEditor.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { getUser } from '@/services/dataService.js'
import { ROLE_LABELS, displayName } from '@/ui/format.js'

// Fiche d'un agent pour son responsable ou l'administration :
// tableau de bord, historique et (administration) rôle / suppression.
export default {
  name: 'MemberView',
  components: { PageHeader, SegmentedTabs, HoursDashboard, ClockHistory, UserAdminCard, PeriodEditor },
  mixins: [loadable],
  props: { id: { type: String, required: true } },
  data: () => ({
    user: null, tab: 'dashboard', version: 0, ROLE_LABELS,
  }),
  computed: {
    userId() { return Number(this.id) },
    me: () => app.user,
    isAdmin: () => app.user.role === 'administrator',
    // Droits du serveur : l'administration, ou le responsable mais jamais pour ses propres heures.
    canEditHours() { return this.isAdmin || (app.user.role === 'manager' && this.userId !== app.user.id) },
    TABS() {
      const tabs = [{ value: 'dashboard', label: t('Graphiques') }, { value: 'history', label: t('Historique') }]
      return this.canEditHours ? [...tabs, { value: 'edit', label: t('Corriger') }] : tabs
    },
  },
  created() { this.load() },
  methods: {
    displayName,
    async load() { this.user = await this.run(() => getUser(this.userId)) },
  },
}
</script>
