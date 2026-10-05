<template>
  <div class="profile">
    <PageHeader eyebrow="Mon compte" title="Mon profil" />

    <div class="layout">
      <form class="card section" novalidate @submit.prevent="saveProfile">
        <h2 class="card-title">Identité</h2>
        <p class="card-subtitle">Votre rôle : <strong>{{ roleLabel }}</strong>. Seule l’administration peut le changer.</p>

        <label class="field">
          <span class="field-label">Identifiant</span>
          <input v-model.trim="profile.username" class="input" :class="{ 'has-error': profileErrors.username }" autocomplete="username" />
          <span v-if="profileErrors.username" class="field-error">{{ profileErrors.username }}</span>
        </label>

        <label class="field">
          <span class="field-label">Adresse e-mail</span>
          <input v-model.trim="profile.email" class="input" :class="{ 'has-error': profileErrors.email }" type="email" autocomplete="email" />
          <span v-if="profileErrors.email" class="field-error">{{ profileErrors.email }}</span>
        </label>

        <p v-if="profileError" class="field-error" role="alert">{{ profileError }}</p>

        <div>
          <button class="btn btn-primary btn-sm" type="submit" :disabled="savingProfile || hasProfileErrors">Enregistrer</button>
        </div>
      </form>

      <form class="card section" novalidate @submit.prevent="savePassword">
        <h2 class="card-title">Mot de passe</h2>
        <p class="card-subtitle">Le mot de passe actuel est demandé : une session ouverte ne suffit pas à changer de mot de passe.</p>

        <label class="field">
          <span class="field-label">Mot de passe actuel</span>
          <input v-model="password.current" class="input" type="password" autocomplete="current-password" />
        </label>

        <label class="field">
          <span class="field-label">Nouveau mot de passe</span>
          <input v-model="password.next" class="input" type="password" autocomplete="new-password" />
          <span class="field-hint">Au moins {{ minLength }} caractères.</span>
        </label>

        <label class="field">
          <span class="field-label">Confirmation</span>
          <input v-model="password.confirmation" class="input" type="password" autocomplete="new-password" />
        </label>

        <p v-if="passwordError" class="field-error" role="alert">{{ passwordError }}</p>

        <div>
          <button class="btn btn-primary btn-sm" type="submit" :disabled="savingPassword">Changer le mot de passe</button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
import PageHeader from './ui/PageHeader.vue'
import * as userService from '../services/userService'
import { auth, ROLE_LABELS, setUser } from '../stores/auth'
import { EMAIL_PATTERN, PASSWORD_MIN_LENGTH } from '../utils/people'
import { notify } from '../utils/toast'

export default {
  name: 'Profile',

  components: { PageHeader },

  data() {
    return {
      profile: { username: auth.user.username, email: auth.user.email },
      password: { current: '', next: '', confirmation: '' },
      minLength: PASSWORD_MIN_LENGTH,
      savingProfile: false,
      savingPassword: false,
      profileError: '',
      passwordError: '',
    }
  },

  computed: {
    roleLabel() {
      return ROLE_LABELS[auth.user.role] || auth.user.role
    },

    profileErrors() {
      const errors = {}
      if (!this.profile.username) errors.username = 'Un identifiant est nécessaire.'
      if (!EMAIL_PATTERN.test(this.profile.email)) errors.email = 'Adresse invalide (ex. nom@domaine.fr).'
      return errors
    },

    hasProfileErrors() {
      return Object.keys(this.profileErrors).length > 0
    },
  },

  methods: {
    async saveProfile() {
      this.savingProfile = true
      this.profileError = ''

      try {
        setUser(await userService.updateUser(auth.user.id, { ...this.profile }))
        notify('Profil mis à jour.')
      } catch (error) {
        this.profileError = error.message
      } finally {
        this.savingProfile = false
      }
    },

    async savePassword() {
      if (this.password.next.length < PASSWORD_MIN_LENGTH) {
        this.passwordError = `Le nouveau mot de passe doit faire au moins ${PASSWORD_MIN_LENGTH} caractères.`
        return
      }
      if (this.password.next !== this.password.confirmation) {
        this.passwordError = 'Les deux nouveaux mots de passe diffèrent.'
        return
      }

      this.savingPassword = true
      this.passwordError = ''

      try {
        await userService.updateUser(auth.user.id, { password: this.password.next, current_password: this.password.current })
        this.password = { current: '', next: '', confirmation: '' }
        notify('Mot de passe changé.')
      } catch (error) {
        this.passwordError = error.payload && error.payload.errors && error.payload.errors.current_password
          ? 'Le mot de passe actuel est incorrect.'
          : error.message
      } finally {
        this.savingPassword = false
      }
    },
  },
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 24px;
  align-items: start;
}

.section {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 24px;
}
</style>
