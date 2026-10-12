<template>
  <PageHeader :title="organization ? organization.name : 'Organisation'" eyebrow="Administration">
    <button type="button" class="btn-outline" :disabled="loading" @click="load()">Actualiser</button>
  </PageHeader>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt" @retry="load">
    <StatTiles :tiles="tiles" />
    <JoinRequests v-if="organization" ref="requests" @count="pendingCount = $event" @changed="load({ quiet: true })" />
    <p v-else class="card notice-card small">
      Ce compte administrateur n’appartient à aucune organisation : il ne reçoit pas de demandes d’adhésion.
      Les demandes arrivent aux administrateurs de l’organisation demandée.
    </p>
    <OrgHours :users="users" />
    <NewUserForm @created="load({ quiet: true })" />
    <MembersList :users="users" />
  </DataState>
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import DataState from '@/components/common/DataState.vue'
import StatTiles from '@/components/dashboard/StatTiles.vue'
import JoinRequests from '@/components/admin/JoinRequests.vue'
import OrgHours from '@/components/admin/OrgHours.vue'
import MembersList from '@/components/admin/MembersList.vue'
import NewUserForm from '@/components/admin/NewUserForm.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { getTeams, getUsers } from '@/services/dataService.js'

const count = (list, role) => list.filter((u) => u.role === role).length

// Tableau de bord de l'administration (comme « Administration » sur le web) :
// chiffres clés, demandes d'adhésion, heures de l'organisation, membres et rôles.
export default {
  name: 'OrgView',
  components: { PageHeader, DataState, StatTiles, JoinRequests, OrgHours, MembersList, NewUserForm },
  mixins: [loadable],
  data: () => ({ users: [], teams: [], pendingCount: 0 }),
  computed: {
    organization: () => app.organization,
    tiles() {
      return [
        { label: 'Demandes en attente', value: this.organization ? String(this.pendingCount) : '—' },
        { label: 'Membres', value: String(this.users.length) },
        { label: 'Managers', value: String(count(this.users, 'manager')) },
        { label: 'Employés', value: String(count(this.users, 'employee')) },
        { label: 'Équipes', value: String(this.teams.length) },
        { label: 'Administrateurs', value: String(count(this.users, 'administrator')) },
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
