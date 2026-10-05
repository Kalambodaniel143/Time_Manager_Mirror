<template>
  <AuthLayout>
    <form class="auth-form" novalidate @submit.prevent="submit">
      <h2 class="page-title">Créer un compte</h2>
      <p class="lede">Votre compte démarre avec le rôle Employé. L’administration vous rattache ensuite à vos équipes.</p>

      <label class="field">
        <span class="field-label">Identifiant</span>
        <input ref="username" v-model.trim="form.username" class="input" :class="{ 'has-error': shown('username') }" autocomplete="username" @blur="touched.username = true" />
        <span v-if="shown('username')" class="field-error">{{ errors.username }}</span>
      </label>

      <label class="field">
        <span class="field-label">Adresse e-mail</span>
        <input v-model.trim="form.email" class="input" :class="{ 'has-error': shown('email') }" type="email" autocomplete="email" @blur="touched.email = true" />
        <span v-if="shown('email')" class="field-error">{{ errors.email }}</span>
      </label>

      <label class="field">
        <span class="field-label">Mot de passe</span>
        <input v-model="form.password" class="input" :class="{ 'has-error': shown('password') }" type="password" autocomplete="new-password" @blur="touched.password = true" />
        <span v-if="shown('password')" class="field-error">{{ errors.password }}</span>
        <span v-else class="field-hint">Au moins 8 caractères.</span>
      </label>

      <label class="field">
        <span class="field-label">Confirmation du mot de passe</span>
        <input v-model="form.confirmation" class="input" :class="{ 'has-error': shown('confirmation') }" type="password" autocomplete="new-password" @blur="touched.confirmation = true" />
        <span v-if="shown('confirmation')" class="field-error">{{ errors.confirmation }}</span>
      </label>

      <p v-if="error" class="field-error" role="alert">{{ error }}</p>

      <div>
        <button class="btn btn-primary btn-login" type="submit" :disabled="loading">
          <AppIcon name="check" />
          {{ loading ? 'Création…' : 'Créer mon compte' }}
        </button>
      </div>

      <p class="switch">
        Déjà un compte ?
        <RouterLink class="link" :to="{ name: 'login' }">Se connecter</RouterLink>
      </p>
    </form>
  </AuthLayout>
</template>

<script>
import { RouterLink } from 'vue-router'
import AppIcon from './ui/AppIcon.vue'
import AuthLayout from './layout/AuthLayout.vue'
import { register } from '../stores/auth'
import { EMAIL_PATTERN, PASSWORD_MIN_LENGTH } from '../utils/people'
import { homeFor } from '../utils/session'

const FIELDS = ['username', 'email', 'password', 'confirmation']

export default {
  name: 'Registration',

  components: { AppIcon, AuthLayout, RouterLink },

  data() {
    return {
      form: { username: '', email: '', password: '', confirmation: '' },
      touched: Object.fromEntries(FIELDS.map((field) => [field, false])),
      error: '',
      loading: false,
    }
  },

  computed: {
    errors() {
      const errors = {}

      if (!this.form.username) errors.username = 'Un identifiant est nécessaire.'
      if (!EMAIL_PATTERN.test(this.form.email)) errors.email = 'Adresse invalide (ex. nom@domaine.fr).'
      if (this.form.password.length < PASSWORD_MIN_LENGTH) errors.password = `Au moins ${PASSWORD_MIN_LENGTH} caractères.`
      if (this.form.confirmation !== this.form.password) errors.confirmation = 'Les deux mots de passe diffèrent.'

      return errors
    },
  },

  mounted() {
    this.$refs.username.focus()
  },

  methods: {
    shown(field) {
      return this.touched[field] && this.errors[field]
    },

    async submit() {
      FIELDS.forEach((field) => (this.touched[field] = true))
      if (Object.keys(this.errors).length > 0) return

      this.loading = true
      this.error = ''

      try {
        const { username, email, password } = this.form
        const user = await register({ username, email, password })
        this.$router.push(homeFor(user.role))
      } catch (error) {
        this.error = error.message
      } finally {
        this.loading = false
      }
    },
  },
}
</script>
