<template>
  <div class="admin-teams">
    <PageHeader :eyebrow="isAdmin ? 'Administration' : 'Mon équipe'" :title="isAdmin ? 'Équipes' : 'Mes équipes'" />

    <InfoNote v-if="!isAdmin" title="Composition des équipes">
      Seule l’administration compose les équipes et nomme leurs managers : sinon, ajouter quelqu’un à son équipe donnerait
      accès à ses heures.
    </InfoNote>

    <p v-if="error" class="field-error" role="alert">{{ error }}</p>
    <div v-else-if="loading" class="skeleton table-skeleton"></div>

    <div v-else class="grid">
      <section v-for="team in teams" :key="team.id" class="card team">
        <header class="team-header">
          <h2 class="card-title">{{ team.name }}</h2>
          <button
            v-if="isAdmin"
            class="btn btn-danger btn-sm"
            :class="{ 'is-armed': armed === team.id }"
            type="button"
            @click="armed === team.id ? remove(team) : (armed = team.id)"
          >
            {{ armed === team.id ? 'Confirmer' : 'Supprimer' }}
          </button>
        </header>

        <label v-if="isAdmin" class="field">
          <span class="field-label">Manager</span>
          <select class="input select" :value="team.manager ? team.manager.id : ''" @change="setManager(team, $event.target.value)">
            <option value="">Aucun</option>
            <option v-for="user in managers" :key="user.id" :value="user.id">{{ user.username }}</option>
          </select>
        </label>
        <p v-else class="card-subtitle">Manager : {{ team.manager ? team.manager.username : 'aucun' }}</p>

        <ul class="members">
          <li v-for="member in team.members" :key="member.id" class="member">
            <RouterLink v-if="canOpen(team)" class="link" :to="{ name: 'workingTimes', params: { userID: member.id } }">
              {{ member.username }}
            </RouterLink>
            <span v-else>{{ member.username }}</span>
            <button v-if="isAdmin" class="btn btn-quiet btn-sm" type="button" @click="removeMember(team, member)">Retirer</button>
          </li>
          <li v-if="team.members.length === 0" class="empty">Aucun membre visible.</li>
        </ul>

        <form v-if="isAdmin" class="add" @submit.prevent="addMember(team)">
          <select v-model="adding[team.id]" class="input select" :aria-label="`Ajouter à ${team.name}`">
            <option :value="undefined" disabled>Ajouter un membre…</option>
            <option v-for="user in candidates(team)" :key="user.id" :value="user.id">{{ user.username }}</option>
          </select>
          <button class="btn btn-outline btn-sm" type="submit" :disabled="!adding[team.id]">Ajouter</button>
        </form>
      </section>

      <form v-if="isAdmin" class="card team create" @submit.prevent="create">
        <h2 class="card-title">Nouvelle équipe</h2>
        <label class="field">
          <span class="field-label">Nom</span>
          <input v-model.trim="newName" class="input" />
        </label>
        <div>
          <button class="btn btn-primary btn-sm" type="submit" :disabled="!newName">Créer l’équipe</button>
        </div>
      </form>

      <p v-if="!isAdmin && teams.length === 0" class="card-subtitle">Vous ne faites partie d’aucune équipe pour le moment.</p>
    </div>
  </div>
</template>

<script>
import { RouterLink } from 'vue-router'
import InfoNote from '../components/ui/InfoNote.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import * as teamService from '../services/teamService'
import { listUsers } from '../services/userService'
import { auth, hasRole } from '../stores/auth'
import { notify } from '../utils/toast'

export default {
  name: 'AdminTeams',

  components: { InfoNote, PageHeader, RouterLink },

  data() {
    return { teams: [], users: [], loading: true, error: '', armed: null, adding: {}, newName: '' }
  },

  computed: {
    isAdmin() {
      return hasRole('administrator')
    },

    managers() {
      return this.users.filter((user) => user.role === 'manager' || user.role === 'administrator')
    },
  },

  async created() {
    try {
      const [teams, users] = await Promise.all([teamService.listTeams(), this.isAdmin ? listUsers() : []])
      this.teams = teams || []
      this.users = users || []
    } catch (error) {
      this.error = error.message
    } finally {
      this.loading = false
    }
  },

  methods: {
    canOpen(team) {
      return this.isAdmin || (team.manager && team.manager.id === auth.user.id)
    },

    candidates(team) {
      const ids = new Set(team.members.map((member) => member.id))
      return this.users.filter((user) => !ids.has(user.id))
    },

    replace(team) {
      this.teams = this.teams.map((other) => (other.id === team.id ? team : other))
    },

    async run(action, success) {
      try {
        await action()
        if (success) notify(success)
      } catch (error) {
        notify(error.message, 'error')
      }
    },

    setManager(team, value) {
      return this.run(async () => this.replace(await teamService.updateTeam(team.id, { manager_id: value ? Number(value) : null })), 'Manager mis à jour.')
    },

    addMember(team) {
      const userId = this.adding[team.id]
      return this.run(async () => {
        this.replace(await teamService.addMember(team.id, userId))
        this.adding[team.id] = undefined
      }, 'Membre ajouté.')
    },

    removeMember(team, member) {
      return this.run(async () => this.replace(await teamService.removeMember(team.id, member.id)), `${member.username} retiré de l’équipe.`)
    },

    remove(team) {
      return this.run(async () => {
        await teamService.deleteTeam(team.id)
        this.teams = this.teams.filter((other) => other.id !== team.id)
        this.armed = null
      }, 'Équipe supprimée.')
    },

    create() {
      return this.run(async () => {
        this.teams.push(await teamService.createTeam({ name: this.newName }))
        this.newName = ''
      }, 'Équipe créée.')
    },
  },
}
</script>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 24px;
  align-items: start;
  margin-top: 24px;
}

.team {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 22px;
}

.team-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.members {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin: 0;
  padding: 0;
  list-style: none;
}

.member {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.empty {
  color: var(--text-muted);
  font-size: 14px;
}

.add {
  display: flex;
  gap: 8px;
}

.select {
  padding: 6px 10px;
}
</style>
