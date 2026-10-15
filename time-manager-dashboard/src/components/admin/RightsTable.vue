<template>
  <section class="card block">
    <h2 class="card-title">{{ $t("Droits des managers") }}</h2>
    <p v-if="error" class="field-error" role="alert">{{ $t(error) }}</p>
    <p v-if="loading" role="status">{{ $t("Chargement des permissions…") }}</p>
    <div class="table-wrap">
      <table class="table">
        <thead>
          <tr>
            <th scope="col">{{ $t("Manager") }}</th>
            <th v-for="column in columns" :key="column.key" scope="col" class="center">{{ $t(column.label) }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="right in rights" :key="right.id">
            <th scope="row">
              <span class="name">{{ right.name }}</span>
              <span class="team">{{ right.team }}</span>
            </th>
            <td v-for="column in columns" :key="column.key" class="center">
              <input
                class="check"
                type="checkbox"
                :checked="right[column.key]"
                :disabled="loading || busy === right.id"
                :aria-label="`${right.name} : ${$t(column.label)}`"
                @change="setRight(right.id, column.key, $event.target.checked)"
              />
              <span class="right-state">{{ $t(right[column.key] ? 'Autorisé' : 'Non autorisé') }}</span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<script>
import { org, setRight, isDemoData } from '../../services/orgService'

import { listTeams } from '../../services/teamService'
import { loadContext, savePermissions, workforce } from '../../services/workforceService'

export default {
  name: 'RightsTable',

  data() {
    return {
      teams: [], loading: false, busy: null, error: '',
      columns: [
        { key: 'validate', label: 'Valider' },
        { key: 'correct', label: 'Corriger' },
        { key: 'publish', label: 'Publier le planning' },
      ],
    }
  },

  async created() { if (this.demo) return; this.loading = true; try { const [teams] = await Promise.all([listTeams(), loadContext()]); this.teams = teams } catch (error) { this.error = error.message } finally { this.loading = false } },
  computed: {
    demo: isDemoData,
    rights() {
      return this.demo ? org.rights : this.teams.filter(team => team.manager && team.manager.role !== 'administrator').map(team => ({ id: team.id, name: [team.manager.first_name, team.manager.last_name].filter(Boolean).join(' ') || team.manager.username, team: team.name, ...(workforce.permissions.find(row => row.team_id === team.id) || {}) }))
    },
  },

  methods: {
    async setRight(id, key, value) {
      if (this.demo) { setRight(id, key, value); return }
      this.busy = id; this.error = ''
      try { await savePermissions(id, { [key]: value }); await loadContext() }
      catch (error) { this.error = error.message }
      finally { this.busy = null }
    },
  },
}
</script>

<style scoped>
.block {
  padding: 22px 26px 12px;
}

.block .card-title {
  margin-bottom: 14px;
  font-size: 19px;
}

.table-wrap {
  overflow-x: auto;
}

.center {
  text-align: center;
}

.name {
  display: block;
  font-size: 16px;
  font-weight: 700;
}

.team {
  display: block;
  font-size: 14px;
  font-weight: 400;
  color: var(--text-muted);
}

.check {
  width: 22px;
  height: 22px;
  accent-color: var(--brand);
}
.right-state { display: block; font-size: 11px; color: var(--text-muted); margin-top: 4px; }
</style>
