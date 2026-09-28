<template>
  <div class="user">
    <button
      class="user-chip"
      type="button"
      :aria-expanded="menuOpen"
      aria-haspopup="menu"
      @click="toggleMenu"
    >
      <span v-if="user" class="avatar avatar-sm" :class="toneOf(user)">{{ initialsOf(user) }}</span>
      <span v-else class="avatar avatar-sm tone-4">?</span>
      <span class="user-chip-name">{{ user ? nameOf(user) : loading ? 'Chargement…' : 'Aucun profil' }}</span>
      <svg class="chevron" :class="{ open: menuOpen }" viewBox="0 0 16 16" aria-hidden="true">
        <path d="M4 6l4 4 4-4" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" />
      </svg>
    </button>

    <Transition name="pop">
      <div v-if="menuOpen" class="menu card" role="menu">
        <div v-if="user" class="menu-profile">
          <span class="avatar avatar-lg" :class="toneOf(user)">{{ initialsOf(user) }}</span>
          <div class="menu-profile-text">
            <span class="menu-profile-name serif">{{ nameOf(user) }}</span>
            <span class="menu-profile-email">{{ user.email }}</span>
            <span class="menu-profile-id">Profil n° {{ user.id }}</span>
          </div>
        </div>

        <div v-if="user" class="menu-row">
          <button class="btn btn-ghost btn-sm" type="button" @click="openEdit">
            <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M10.5 2.5l3 3L6 13H3v-3z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" /></svg>
            Modifier
          </button>
          <button
            class="btn btn-danger btn-sm"
            :class="{ 'is-armed': deleteArmed }"
            type="button"
            :disabled="deleting"
            @click="deleteArmed ? deleteUser() : armDelete()"
          >
            {{ deleting ? 'Suppression…' : deleteArmed ? 'Vraiment supprimer ?' : 'Supprimer' }}
          </button>
        </div>

        <div class="menu-section">
          <p class="eyebrow">Changer de profil</p>
          <input
            v-model="query"
            class="input menu-search"
            type="search"
            placeholder="Rechercher un nom ou un e-mail"
            aria-label="Rechercher un profil"
          />
          <ul class="menu-users">
            <li v-for="option in filteredUsers" :key="option.id">
              <button
                class="menu-user"
                :class="{ active: option.id === Number(userId) }"
                type="button"
                @click="selectUser(option.id)"
              >
                <span class="avatar avatar-sm" :class="toneOf(option)">{{ initialsOf(option) }}</span>
                <span class="menu-user-text">
                  <span class="menu-user-name">{{ nameOf(option) }}</span>
                  <span class="menu-user-email">{{ option.email }}</span>
                </span>
                <svg v-if="option.id === Number(userId)" class="check" viewBox="0 0 16 16" aria-hidden="true">
                  <path d="M3.5 8.5l3 3 6-7" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </button>
            </li>
            <li v-if="filteredUsers.length === 0" class="menu-empty">Personne ne correspond à « {{ query }} ».</li>
          </ul>
        </div>

        <button class="menu-create" type="button" @click="openCreate">
          <span class="menu-create-icon" aria-hidden="true">+</span>
          Créer un nouveau profil
        </button>
      </div>
    </Transition>

    <Teleport to="body">
      <div v-if="formOpen" class="overlay" @click.self="closeForm">
        <form class="dialog card" novalidate @submit.prevent="submitForm">
          <header class="dialog-header">
            <div>
              <p class="eyebrow">{{ formMode === 'create' ? 'Nouveau profil' : 'Profil' }}</p>
              <h3 class="card-title">
                {{ formMode === 'create' ? 'Faisons connaissance' : `Modifier ${nameOf(user)}` }}
              </h3>
            </div>
            <button class="btn btn-quiet btn-icon btn-sm" type="button" aria-label="Fermer" @click="closeForm">
              <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M4 4l8 8M12 4l-8 8" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" /></svg>
            </button>
          </header>

          <div class="dialog-body">
            <div class="form-preview">
              <span class="avatar avatar-lg" :class="toneOf(form)">{{ initialsOf(form) }}</span>
              <div>
                <p class="form-preview-name serif">{{ nameOf(form) || 'Votre nom ici' }}</p>
                <p class="form-preview-email">{{ form.email || 'adresse@gotham.gov' }}</p>
              </div>
            </div>

            <div class="field">
              <label class="field-label" for="user-username">Identifiant</label>
              <input
                id="user-username"
                ref="username"
                v-model.trim="form.username"
                class="input"
                :class="{ 'has-error': touched.username && formErrors.username }"
                type="text"
                autocomplete="username"
                placeholder="prenom.nom"
                @blur="touched.username = true"
              />
              <span v-if="touched.username && formErrors.username" class="field-error">{{ formErrors.username }}</span>
              <span v-else class="field-hint">Le format prénom.nom donne un joli nom d'affichage.</span>
            </div>

            <div class="field">
              <label class="field-label" for="user-email">Adresse e-mail</label>
              <input
                id="user-email"
                v-model.trim="form.email"
                class="input"
                :class="{ 'has-error': touched.email && formErrors.email }"
                type="email"
                autocomplete="email"
                placeholder="prenom.nom@gotham.gov"
                @blur="touched.email = true"
              />
              <span v-if="touched.email && formErrors.email" class="field-error">{{ formErrors.email }}</span>
            </div>

            <p v-if="formError" class="form-error">{{ formError }}</p>
          </div>

          <footer class="dialog-footer">
            <span class="spacer"></span>
            <button class="btn btn-ghost" type="button" :disabled="saving" @click="closeForm">Annuler</button>
            <button class="btn btn-primary" type="submit" :disabled="saving">
              {{ saving ? 'Enregistrement…' : formMode === 'create' ? 'Créer le profil' : 'Enregistrer' }}
            </button>
          </footer>
        </form>
      </div>
    </Teleport>
  </div>
</template>

<script>
import * as userService from '../services/userService'
import { EMAIL_PATTERN, displayName, initials, toneClass } from '../utils/people'
import { notify } from '../utils/toast'

export default {
  name: 'User',

  props: {
    userId: { type: [Number, String], default: null },
  },

  emits: ['update:userId', 'loaded'],

  data() {
    return {
      user: null,
      users: [],
      loading: false,
      menuOpen: false,
      query: '',
      formOpen: false,
      formMode: 'create',
      form: { username: '', email: '' },
      touched: { username: false, email: false },
      saving: false,
      formError: '',
      deleteArmed: false,
      deleting: false,
      disarmTimer: null,
    }
  },

  computed: {
    filteredUsers() {
      const needle = this.query.trim().toLowerCase()
      if (!needle) return this.users

      return this.users.filter(
        (option) =>
          displayName(option).toLowerCase().includes(needle) ||
          option.email.toLowerCase().includes(needle),
      )
    },

    formErrors() {
      const errors = {}

      if (!this.form.username) errors.username = 'Un identifiant est nécessaire.'
      else if (this.form.username.length < 3) errors.username = 'Au moins 3 caractères, s’il vous plaît.'

      if (!this.form.email) errors.email = 'Une adresse e-mail est nécessaire.'
      else if (!EMAIL_PATTERN.test(this.form.email)) errors.email = 'Cette adresse ne semble pas valide (ex. nom@domaine.fr).'

      return errors
    },
  },

  watch: {
    userId: {
      immediate: true,
      handler() {
        this.getUser()
      },
    },
  },

  mounted() {
    this.loadUsers()
    document.addEventListener('pointerdown', this.onDocumentPointer)
    document.addEventListener('keydown', this.onKeydown)
  },

  beforeUnmount() {
    document.removeEventListener('pointerdown', this.onDocumentPointer)
    document.removeEventListener('keydown', this.onKeydown)
    clearTimeout(this.disarmTimer)
  },

  methods: {
    nameOf(user) {
      return displayName(user)
    },

    initialsOf(user) {
      return initials(user)
    },

    toneOf(user) {
      return toneClass(user)
    },

    async getUser() {
      if (this.userId === null || this.userId === undefined || this.userId === '') {
        this.user = null
        this.$emit('loaded', null)
        return
      }

      this.loading = true

      try {
        this.user = await userService.getUser(this.userId)
      } catch (error) {
        this.user = null
        if (error.status !== 404) notify(`Impossible de charger ce profil : ${error.message}`, 'error')
      } finally {
        this.loading = false
      }

      if (this.user) this.$emit('loaded', this.user)
      else await this.recoverMissingUser()
    },

    async recoverMissingUser() {
      if (this.users.length === 0) await this.loadUsers()

      const fallback = this.users.find((option) => option.id !== Number(this.userId))
      this.$emit('update:userId', fallback ? fallback.id : null)
    },

    async loadUsers() {
      try {
        this.users = (await userService.listUsers()) || []
      } catch (error) {
        notify(`La liste des profils est indisponible : ${error.message}`, 'error')
      }
    },

    async findEmailOwner(email) {
      const matches = (await userService.listUsers({ email })) || []
      return matches.find((match) => this.formMode === 'create' || match.id !== this.user.id) || null
    },

    async createUser() {
      this.saving = true
      this.formError = ''

      try {
        const owner = await this.findEmailOwner(this.form.email)
        if (owner) {
          this.formError = `Cette adresse est déjà utilisée par ${displayName(owner)}.`
          return
        }

        const created = await userService.createUser({ ...this.form })
        this.users = [...this.users, created]
        this.formOpen = false
        notify(`Bienvenue, ${displayName(created)} ! Le profil est prêt.`)
        this.$emit('update:userId', created.id)
      } catch (error) {
        this.formError = error.message
      } finally {
        this.saving = false
      }
    },

    async updateUser() {
      this.saving = true
      this.formError = ''

      try {
        if (this.form.email !== this.user.email) {
          const owner = await this.findEmailOwner(this.form.email)
          if (owner) {
            this.formError = `Cette adresse est déjà utilisée par ${displayName(owner)}.`
            return
          }
        }

        const updated = await userService.updateUser(this.user.id, { ...this.form })
        this.user = updated
        this.users = this.users.map((option) => (option.id === updated.id ? updated : option))
        this.formOpen = false
        this.$emit('loaded', updated)
        notify('Profil mis à jour.')
      } catch (error) {
        this.formError = error.message
      } finally {
        this.saving = false
      }
    },

    async deleteUser() {
      if (!this.user) return

      const removed = this.user
      this.deleting = true
      clearTimeout(this.disarmTimer)

      try {
        await userService.deleteUser(removed.id)
        this.users = this.users.filter((option) => option.id !== removed.id)
        this.deleteArmed = false
        this.menuOpen = false
        notify(`Le profil de ${displayName(removed)} a été supprimé.`)

        const next = this.users[0]
        this.$emit('update:userId', next ? next.id : null)
      } catch (error) {
        notify(`Suppression impossible : ${error.message}`, 'error')
      } finally {
        this.deleting = false
      }
    },

    armDelete() {
      this.deleteArmed = true
      clearTimeout(this.disarmTimer)
      this.disarmTimer = setTimeout(() => {
        this.deleteArmed = false
      }, 4000)
    },

    selectUser(id) {
      this.menuOpen = false
      this.query = ''
      if (id !== Number(this.userId)) this.$emit('update:userId', id)
    },

    toggleMenu() {
      this.menuOpen = !this.menuOpen
      if (!this.menuOpen) this.resetMenu()
    },

    resetMenu() {
      this.query = ''
      this.deleteArmed = false
      clearTimeout(this.disarmTimer)
    },

    openCreate() {
      this.openForm('create', { username: '', email: '' })
    },

    openEdit() {
      if (!this.user) return
      this.openForm('edit', { username: this.user.username, email: this.user.email })
    },

    openForm(mode, values) {
      this.formMode = mode
      this.form = { ...values }
      this.touched = { username: false, email: false }
      this.formError = ''
      this.menuOpen = false
      this.resetMenu()
      this.formOpen = true
      this.$nextTick(() => this.$refs.username && this.$refs.username.focus())
    },

    closeForm() {
      if (!this.saving) this.formOpen = false
    },

    submitForm() {
      this.touched = { username: true, email: true }
      if (Object.keys(this.formErrors).length > 0) return

      return this.formMode === 'create' ? this.createUser() : this.updateUser()
    },

    onDocumentPointer(event) {
      if (this.menuOpen && !this.$el.contains(event.target)) {
        this.menuOpen = false
        this.resetMenu()
      }
    },

    onKeydown(event) {
      if (event.key !== 'Escape') return

      if (this.formOpen) this.closeForm()
      else if (this.menuOpen) {
        this.menuOpen = false
        this.resetMenu()
      }
    },
  },
}
</script>

<style scoped>
.user {
  position: relative;
}

.user-chip {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 4px 10px 4px 4px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 999px;
  transition: border-color 0.15s ease, background-color 0.15s ease;
}

.user-chip:hover {
  border-color: var(--border-strong);
  background: var(--surface-hover);
}

.user-chip-name {
  max-width: 160px;
  overflow: hidden;
  font-size: 13.5px;
  font-weight: 500;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.chevron {
  width: 14px;
  height: 14px;
  color: var(--text-muted);
  transition: transform 0.2s ease;
}

.chevron.open {
  transform: rotate(180deg);
}

.menu {
  position: absolute;
  top: calc(100% + 10px);
  right: 0;
  z-index: 50;
  width: 330px;
  max-width: calc(100vw - 32px);
  box-shadow: var(--shadow);
  overflow: hidden;
}

.menu-profile {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 20px 20px 14px;
}

.menu-profile-text {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.menu-profile-name {
  font-size: 18px;
  line-height: 1.25;
}

.menu-profile-email {
  overflow: hidden;
  font-size: 13px;
  color: var(--text-muted);
  white-space: nowrap;
  text-overflow: ellipsis;
}

.menu-profile-id {
  font-size: 11.5px;
  color: var(--text-subtle);
}

.menu-row {
  display: flex;
  gap: 8px;
  padding: 0 20px 16px;
}

.menu-row .btn {
  flex: 1;
}

.menu-section {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 16px 20px 8px;
  border-top: 1px solid var(--border);
}

.menu-search {
  padding: 8px 12px;
  font-size: 13px;
}

.menu-users {
  display: flex;
  flex-direction: column;
  gap: 2px;
  max-height: 232px;
  margin: 0 -8px;
  padding: 0;
  overflow-y: auto;
  list-style: none;
}

.menu-user {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 8px;
  background: transparent;
  border: none;
  border-radius: var(--radius-sm);
  text-align: left;
  transition: background-color 0.12s ease;
}

.menu-user:hover {
  background: var(--surface-hover);
}

.menu-user.active {
  background: var(--accent-soft);
}

.menu-user-text {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-width: 0;
  line-height: 1.3;
}

.menu-user-name {
  font-size: 13.5px;
  font-weight: 500;
}

.menu-user-email {
  overflow: hidden;
  font-size: 12px;
  color: var(--text-muted);
  white-space: nowrap;
  text-overflow: ellipsis;
}

.check {
  width: 16px;
  height: 16px;
  color: var(--accent);
}

.menu-empty {
  padding: 10px 8px;
  font-size: 13px;
  color: var(--text-muted);
}

.menu-create {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 14px 20px;
  background: var(--surface-muted);
  border: none;
  border-top: 1px solid var(--border);
  font-size: 13.5px;
  font-weight: 500;
  color: var(--accent);
  text-align: left;
  transition: background-color 0.12s ease;
}

.menu-create:hover {
  background: var(--surface-hover);
}

.menu-create-icon {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border: 1.5px dashed currentColor;
  border-radius: 50%;
  font-size: 16px;
  line-height: 1;
}

.form-preview {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px;
  background: var(--surface-muted);
  border-radius: var(--radius);
}

.form-preview-name {
  font-size: 18px;
  line-height: 1.25;
}

.form-preview-email {
  font-size: 13px;
  color: var(--text-muted);
}

.form-error {
  padding: 11px 14px;
  background: var(--danger-soft);
  border-radius: var(--radius-sm);
  font-size: 13px;
  color: var(--danger);
}

@media (max-width: 560px) {
  .user-chip-name {
    display: none;
  }

  .user-chip {
    padding-right: 8px;
  }
}
</style>
