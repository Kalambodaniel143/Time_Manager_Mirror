<template>
  <div class="user-card">
    <button class="avatar" type="button" :aria-label="`Profil de ${persona.name}`" @click="openEdit">{{ badge }}</button>
    <div class="user-text">
      <button class="user-name" type="button" @click="openEdit">{{ persona.name }}</button>
      <p class="user-job">{{ persona.job }}</p>
      <button class="user-logout" type="button" @click="$emit('logout')">Se déconnecter</button>
    </div>

    <Teleport to="body">
      <div v-if="formOpen" class="overlay" @click.self="closeForm">
        <form class="dialog card" role="dialog" aria-modal="true" aria-labelledby="profile-title" novalidate @submit.prevent="submitForm">
          <header class="dialog-header">
            <div>
              <p class="eyebrow">Mon profil</p>
              <h2 id="profile-title" class="card-title">{{ persona.name }}</h2>
              <p class="card-subtitle">Identifiant et adresse enregistrés dans Time Manager.</p>
            </div>
            <button class="btn btn-quiet btn-icon btn-sm" type="button" aria-label="Fermer" @click="closeForm">
              <AppIcon name="close" />
            </button>
          </header>

          <div class="dialog-body">
            <label class="field">
              <span class="field-label">Identifiant</span>
              <input
                ref="username"
                v-model.trim="form.username"
                class="input"
                :class="{ 'has-error': touched.username && formErrors.username }"
                autocomplete="username"
                @blur="touched.username = true"
              />
              <span v-if="touched.username && formErrors.username" class="field-error">{{ formErrors.username }}</span>
            </label>

            <label class="field">
              <span class="field-label">Adresse e-mail</span>
              <input
                v-model.trim="form.email"
                class="input"
                :class="{ 'has-error': touched.email && formErrors.email }"
                type="email"
                autocomplete="email"
                @blur="touched.email = true"
              />
              <span v-if="touched.email && formErrors.email" class="field-error">{{ formErrors.email }}</span>
            </label>

            <p v-if="formError" class="field-error" role="alert">{{ formError }}</p>
          </div>

          <footer class="dialog-footer">
            <button
              class="btn btn-danger btn-sm"
              :class="{ 'is-armed': deleteArmed }"
              type="button"
              :disabled="deleting || !user"
              @click="deleteArmed ? deleteUser() : armDelete()"
            >
              {{ deleteArmed ? 'Confirmer la suppression' : 'Supprimer le profil' }}
            </button>
            <span class="spacer"></span>
            <button class="btn btn-ghost btn-sm" type="button" @click="closeForm">Annuler</button>
            <button class="btn btn-primary btn-sm" type="submit" :disabled="saving || !user">Enregistrer</button>
          </footer>
        </form>
      </div>
    </Teleport>
  </div>
</template>

<script>
import AppIcon from './ui/AppIcon.vue'
import * as userService from '../services/userService'
import { EMAIL_PATTERN } from '../utils/people'
import { notify } from '../utils/toast'

export default {
  name: 'User',

  components: { AppIcon },

  props: {
    persona: { type: Object, required: true },
    userId: { type: [Number, String], default: null },
  },

  emits: ['update:userId', 'loaded', 'logout'],

  data() {
    return {
      user: null,
      formOpen: false,
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
    badge() {
      const parts = this.persona.name.split(' ').filter(Boolean)
      return parts.map((part) => part[0]).join('').slice(0, 2).toUpperCase()
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
    'persona.username': {
      immediate: true,
      handler() {
        this.resolveUser()
      },
    },
  },

  mounted() {
    document.addEventListener('keydown', this.onKeydown)
  },

  beforeUnmount() {
    document.removeEventListener('keydown', this.onKeydown)
    clearTimeout(this.disarmTimer)
  },

  methods: {
    async resolveUser() {
      try {
        const matches = (await userService.listUsers({ username: this.persona.username })) || []
        const found = matches.find((match) => match.username === this.persona.username)
        this.user = found || (await this.createUser())
      } catch (error) {
        this.user = null
        notify(`Profil indisponible : ${error.message}`, 'error')
      }

      this.$emit('update:userId', this.user ? this.user.id : null)
      this.$emit('loaded', this.user)
    },

    async getUser() {
      if (!this.userId) return

      try {
        this.user = await userService.getUser(this.userId)
        this.$emit('loaded', this.user)
      } catch (error) {
        notify(`Impossible de charger ce profil : ${error.message}`, 'error')
      }
    },

    createUser() {
      return userService.createUser({ username: this.persona.username, email: this.persona.email })
    },

    async updateUser() {
      this.saving = true
      this.formError = ''

      try {
        if (this.form.email !== this.user.email) {
          const owners = (await userService.listUsers({ email: this.form.email })) || []
          if (owners.some((owner) => owner.id !== this.user.id)) {
            this.formError = 'Cette adresse est déjà utilisée par un autre agent.'
            return
          }
        }

        this.user = await userService.updateUser(this.user.id, { ...this.form })
        this.formOpen = false
        this.$emit('loaded', this.user)
        notify('Profil mis à jour.')
      } catch (error) {
        this.formError = error.message
      } finally {
        this.saving = false
      }
    },

    async deleteUser() {
      if (!this.user) return

      this.deleting = true
      clearTimeout(this.disarmTimer)

      try {
        await userService.deleteUser(this.user.id)
        this.user = null
        this.formOpen = false
        notify('Profil supprimé.')
        this.$emit('update:userId', null)
        this.$emit('logout')
      } catch (error) {
        notify(`Suppression impossible : ${error.message}`, 'error')
      } finally {
        this.deleting = false
        this.deleteArmed = false
      }
    },

    armDelete() {
      this.deleteArmed = true
      clearTimeout(this.disarmTimer)
      this.disarmTimer = setTimeout(() => {
        this.deleteArmed = false
      }, 4000)
    },

    openEdit() {
      if (!this.user) return

      this.form = { username: this.user.username, email: this.user.email }
      this.touched = { username: false, email: false }
      this.formError = ''
      this.deleteArmed = false
      this.formOpen = true
      this.$nextTick(() => this.$refs.username && this.$refs.username.focus())
    },

    closeForm() {
      if (!this.saving) this.formOpen = false
    },

    submitForm() {
      this.touched = { username: true, email: true }
      if (Object.keys(this.formErrors).length > 0) return

      return this.updateUser()
    },

    onKeydown(event) {
      if (event.key === 'Escape' && this.formOpen) this.closeForm()
    },
  },
}
</script>

<style scoped>
.user-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-top: 18px;
  border-top: 1px solid rgba(255, 255, 255, 0.25);
}

.avatar {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 46px;
  height: 46px;
  background: #ffffff;
  border: none;
  border-radius: 50%;
  color: #0037ff;
  font-size: 15px;
  font-weight: 700;
}

.user-text {
  min-width: 0;
}

.user-name {
  padding: 0;
  background: none;
  border: none;
  color: var(--side-ink);
  font-size: 15.5px;
  font-weight: 700;
  text-align: left;
}

.user-job {
  font-size: 14px;
  color: var(--side-muted);
}

.user-logout {
  padding: 0;
  background: none;
  border: none;
  color: var(--side-ink);
  font-size: 14px;
  text-decoration: underline;
  text-underline-offset: 3px;
}
</style>
