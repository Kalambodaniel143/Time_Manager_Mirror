<template>
  <PageHeader :title="organization ? organization.name : $t('Organisation')" :eyebrow="$t('Administration')">
    <template #action><RefreshButton :busy="loading" @refresh="load()" /></template>
  </PageHeader>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt" @retry="load">
    <StatTiles :tiles="tiles" hero compact />
    <SegmentedTabs v-model="tab" :options="tabs" :label="$t('Rubrique')" />
    <!-- v-show : la liste des demandes reste chargée (compteur et mot de passe à transmettre) -->
    <div v-show="tab === 'requests'">
      <JoinRequests v-if="organization" ref="requests" @count="pendingCount = $event" @changed="load({ quiet: true })" />
      <p v-else class="card notice-card small">
        {{ $t('Ce compte administrateur n’appartient à aucune organisation : il ne reçoit pas de demandes d’adhésion.') }}
      </p>
    </div>
    <MembersList v-if="tab === 'members'" :users="users" />
    <OrgHours v-if="tab === 'hours'" :users="users" />
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import RefreshButton from '@/components/common/RefreshButton.vue'
import DataState from '@/components/common/DataState.vue'
import StatTiles from '@/components/dashboard/StatTiles.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import JoinRequests from '@/components/admin/JoinRequests.vue'
import OrgHours from '@/components/admin/OrgHours.vue'
import MembersList from '@/components/admin/MembersList.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { plural } from '@/ui/format.js'
import { getTeams, getUsers } from '@/services/dataService.js'

const count = (list, role) => list.filter((u) => u.role === role).length

// Tableau de bord de l'administration (comme « Administration » sur le web) :
// chiffres clés puis une rubrique à la fois (demandes, membres, heures),
// pour éviter une page interminable sur téléphone. Comme sur le web, pas de création
// directe de compte : les comptes naissent de l'acceptation des demandes (POST /users = 403).
export default {
  name: 'OrgView',
  components: { PageHeader, RefreshButton, DataState, StatTiles, SegmentedTabs, JoinRequests, OrgHours, MembersList },
  mixins: [loadable],
  data: () => ({ users: [], teams: [], pendingCount: 0, tab: 'requests' }),
  computed: {
    organization: () => app.organization,
    tabs() {
      return [
        { value: 'requests', label: `${t('Demandes')}${this.pendingCount ? ` (${this.pendingCount})` : ''}` },
        { value: 'members', label: t('Membres') },
        { value: 'hours', label: t('Heures') },
      ]
    },
    tiles() {
      return [
        { label: t('Membres'), value: String(this.users.length),
          hint: [plural(count(this.users, 'manager'), 'manager'), plural(count(this.users, 'employee'), t('employé')), plural(count(this.users, 'administrator'), 'admin')].join(' · ') },
        { label: t('En attente'), value: this.organization ? String(this.pendingCount) : '—' },
        { label: t('Équipes'), value: String(this.teams.length) },
        { label: t('Managers'), value: String(count(this.users, 'manager')) },
      ]
    },
  },
  created() { this.load() },
  methods: {
    // quiet : après une décision, on rafraîchit sans masquer la page
    // (l'encadré du mot de passe à transmettre doit rester visible).
    async load(options = {}) {
      this.users = (await this.run(() => getUsers(), options)) ?? []
      this.teams = (await this.run(() => getTeams(), { quiet: true })) ?? []
      if (!options.quiet) this.$refs.requests?.load()
    },
  },
}
</script>
