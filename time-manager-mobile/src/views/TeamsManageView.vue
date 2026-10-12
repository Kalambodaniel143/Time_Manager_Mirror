<template>
  <PageHeader title="Gérer les équipes" eyebrow="Administration">
    <button type="button" class="btn-quiet back-link" @click="$router.back()">‹ Retour</button>
  </PageHeader>
  <form class="card form-grid" @submit.prevent="create">
    <h2>Nouvelle équipe</h2>
    <label for="team-name">Nom</label>
    <input id="team-name" v-model.trim="name" required placeholder="ex. Voirie nuit" />
    <label for="team-manager">Responsable</label>
    <select id="team-manager" v-model="managerId">
      <option :value="null">Aucun pour l’instant</option>
      <option v-for="u in managers" :key="u.id" :value="u.id">{{ displayName(u) }}</option>
    </select>
    <p v-if="message" class="notice-danger small" role="alert">{{ message }}</p>
    <button type="submit">Créer l’équipe</button>
  </form>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!teams.length" empty-text="Aucune équipe." @retry="load">
    <TeamEditor v-for="t in teams" :key="t.id" :team="t" :users="users" @changed="load" />
  </DataState>
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import DataState from '@/components/common/DataState.vue'
import TeamEditor from '@/components/admin/TeamEditor.vue'
import loadable from '@/ui/loadable.js'
import { getTeams, getUsers } from '@/services/dataService.js'
import { createTeam } from '@/services/manageService.js'
import { displayName } from '@/ui/format.js'

// Composer les équipes est une tâche d'administration (règle du serveur).
export default {
  name: 'TeamsManageView',
  components: { PageHeader, DataState, TeamEditor },
  mixins: [loadable],
  data: () => ({ teams: [], users: [], name: '', managerId: null, message: '' }),
  computed: {
    managers() { return this.users.filter((u) => u.role !== 'employee') },
  },
  created() { this.load() },
  methods: {
    displayName,
    async load() {
      this.users = (await this.run(() => getUsers())) ?? []
      this.teams = (await this.run(() => getTeams(), { quiet: true })) ?? []
    },
    async create() {
      this.message = ''
      try {
        await createTeam({ name: this.name, manager_id: this.managerId })
        this.name = ''
        this.load()
      } catch (error) {
        this.message = error.message
      }
    },
  },
}
</script>
