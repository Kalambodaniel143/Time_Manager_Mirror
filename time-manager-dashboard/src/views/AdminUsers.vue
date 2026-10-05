<template>
  <div class="admin-users">
    <PageHeader eyebrow="Administration" title="Utilisateurs et rôles" />

    <div class="layout">
      <section class="card accounts">
        <header class="accounts-header">
          <h2 class="card-title">Comptes</h2>
          <p class="card-subtitle">Le changement de rôle s’applique dès la requête suivante de la personne. Vous ne pouvez pas changer votre propre rôle.</p>
        </header>

        <p v-if="error" class="field-error" role="alert">{{ error }}</p>
        <div v-else-if="loading" class="skeleton table-skeleton"></div>

        <div v-else class="table-scroll">
        <table class="table">
          <thead>
            <tr>
              <th scope="col">Identifiant</th>
              <th scope="col">E-mail</th>
              <th scope="col">Rôle</th>
              <th scope="col"><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="user in users" :key="user.id">
              <td>{{ user.username }}<span v-if="user.id === me.id" class="you">vous</span></td>
              <td class="email">{{ user.email }}</td>
              <td>
                <select
                  class="input select"
                  :value="user.role"
                  :disabled="user.id === me.id || busy === user.id"
                  :aria-label="`Rôle de ${user.username}`"
                  @change="changeRole(user, $event.target.value)"
                >
                  <option v-for="role in roles" :key="role" :value="role">{{ labels[role] }}</option>
                </select>
              </td>
              <td class="actions">
                <button
                  class="btn btn-danger btn-sm"
                  :class="{ 'is-armed': armed === user.id }"
                  type="button"
                  :disabled="user.id === me.id || busy === user.id"
                  @click="armed === user.id ? remove(user) : (armed = user.id)"
                >
                  {{ armed === user.id ? 'Confirmer' : 'Supprimer' }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        </div>
      </section>

      <form class="card create" novalidate @submit.prevent="create">
        <h2 class="card-title">Créer un compte</h2>

        <label class="field">
          <span class="field-label">Identifiant</span>
          <input v-model.trim="form.username" class="input" autocomplete="off" />
        </label>
        <label class="field">
          <span class="field-label">Adresse e-mail</span>
          <input v-model.trim="form.email" class="input" type="email" autocomplete="off" />
        </label>
        <label class="field">
          <span class="field-label">Mot de passe provisoire</span>
          <input v-model="form.password" class="input" type="password" autocomplete="new-password" />
          <span class="field-hint">Au moins {{ minLength }} caractères, à changer par la personne depuis son profil.</span>
        </label>
        <label class="field">
          <span class="field-label">Rôle</span>
          <select v-model="form.role" class="input select">
            <option v-for="role in roles" :key="role" :value="role">{{ labels[role] }}</option>
          </select>
        </label>

        <p v-if="formError" class="field-error" role="alert">{{ formError }}</p>

        <div>
          <button class="btn btn-primary btn-sm" type="submit" :disabled="creating">Créer le compte</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
import PageHeader from '../components/ui/PageHeader.vue'
import { listRoles, updateRole } from '../services/authService'
import * as userService from '../services/userService'
import { auth, ROLE_LABELS } from '../stores/auth'
import { EMAIL_PATTERN, PASSWORD_MIN_LENGTH } from '../utils/people'
import { notify } from '../utils/toast'

const EMPTY_FORM = { username: '', email: '', password: '', role: 'employee' }

export default {
  name: 'AdminUsers',

  components: { PageHeader },

  data() {
    return {
      users: [],
      roles: ['employee', 'manager', 'administrator'],
      labels: ROLE_LABELS,
      loading: true,
      error: '',
      busy: null,
      armed: null,
      form: { ...EMPTY_FORM },
      formError: '',
      creating: false,
      minLength: PASSWORD_MIN_LENGTH,
    }
  },

  computed: {
    me() {
      return auth.user
    },
  },

  async created() {
    try {
      const [users, roles] = await Promise.all([userService.listUsers(), listRoles()])
      this.users = users || []
      this.roles = (roles || []).map((role) => role.name)
    } catch (error) {
      this.error = error.message
    } finally {
      this.loading = false
    }
  },

  methods: {
    async changeRole(user, role) {
      this.busy = user.id
      const previous = user.role

      try {
        Object.assign(user, await updateRole(user.id, role))
        notify(`${user.username} est maintenant ${ROLE_LABELS[user.role].toLowerCase()}.`)
      } catch (error) {
        user.role = previous
        notify(error.status === 409 ? 'Il doit rester au moins un administrateur.' : error.message, 'error')
      } finally {
        this.busy = null
      }
    },

    async remove(user) {
      this.busy = user.id

      try {
        await userService.deleteUser(user.id)
        this.users = this.users.filter((other) => other.id !== user.id)
        notify(`Compte ${user.username} supprimé.`)
      } catch (error) {
        notify(error.status === 409 ? 'Il doit rester au moins un administrateur.' : error.message, 'error')
      } finally {
        this.busy = null
        this.armed = null
      }
    },

    async create() {
      if (!this.form.username || !EMAIL_PATTERN.test(this.form.email) || this.form.password.length < PASSWORD_MIN_LENGTH) {
        this.formError = `Identifiant, e-mail valide et mot de passe de ${PASSWORD_MIN_LENGTH} caractères minimum.`
        return
      }

      this.creating = true
      this.formError = ''

      try {
        this.users.push(await userService.createUser({ ...this.form }))
        notify(`Compte ${this.form.username} créé.`)
        this.form = { ...EMPTY_FORM }
      } catch (error) {
        this.formError = error.message
      } finally {
        this.creating = false
      }
    },
  },
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: minmax(0, 2fr) minmax(280px, 1fr);
  gap: 24px;
  align-items: start;
}

.accounts {
  padding: 22px 22px 14px;
}

.accounts-header {
  margin-bottom: 12px;
}

.layout > * {
  min-width: 0;
}

.table-scroll {
  position: relative;
  overflow-x: auto;
}

.table {
  width: 100%;
  min-width: 560px;
  border-collapse: collapse;
  font-size: 15px;
}

.table th {
  padding: 10px 8px;
  border-bottom: 1px solid var(--border);
  color: var(--text-muted);
  font-size: 13px;
  font-weight: 700;
  text-align: left;
}

.table td {
  padding: 10px 8px;
  border-bottom: 1px solid var(--border);
  vertical-align: middle;
}

.email {
  overflow-wrap: anywhere;
}

.select {
  padding: 6px 10px;
}

.actions {
  text-align: right;
}

.you {
  margin-left: 8px;
  color: var(--text-muted);
  font-size: 13px;
}

.create {
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding: 22px;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
}

@media (max-width: 900px) {
  .layout {
    grid-template-columns: 1fr;
  }

}
</style>
