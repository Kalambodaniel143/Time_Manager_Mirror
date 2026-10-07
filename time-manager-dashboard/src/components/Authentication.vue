<template>
  <AuthLayout>
    <form class="auth-form" novalidate @submit.prevent="submit">
      <h2 class="page-title">Connexion</h2>
      <p class="lede">Connectez-vous avec l’adresse e-mail et le mot de passe fournis par l’administration.</p>

      <label class="field">
        <span class="field-label">Adresse e-mail</span>
        <input ref="email" v-model.trim="email" class="input" type="email" autocomplete="username" required />
      </label>

      <label class="field">
        <span class="field-label">Mot de passe</span>
        <span class="password-control"><input v-model="password" class="input" :type="showLoginPassword ? 'text' : 'password'" autocomplete="current-password" required /><button class="password-toggle" type="button" :aria-label="showLoginPassword ? 'Masquer le mot de passe' : 'Afficher le mot de passe'" :aria-pressed="showLoginPassword" @click="showLoginPassword = !showLoginPassword"><AppIcon :name="showLoginPassword ? 'eye-off' : 'eye'" /></button></span>
      </label>

      <p v-if="error" class="field-error" role="alert">{{ error }}</p>

      <div>
        <button class="btn btn-primary btn-login" type="submit" :disabled="loading">
          <AppIcon name="login" />
          {{ loading ? 'Connexion…' : 'Se connecter' }}
        </button>
      </div>

      <p class="switch">
        Pas encore de compte ?
        <RouterLink class="link" :to="{ name: 'register' }">Créer un compte</RouterLink>
      </p>
    </form>
  </AuthLayout>
</template>

<script>
import { RouterLink } from 'vue-router'
import AppIcon from './ui/AppIcon.vue'
import AuthLayout from './layout/AuthLayout.vue'
import { login } from '../stores/auth'
import { homeFor } from '../utils/session'

export default {
  name: 'Authentication',

  components: { AppIcon, AuthLayout, RouterLink },

  data() {
    return { showLoginPassword: false, email: '', password: '', error: '', loading: false }
  },

  mounted() {
    this.$refs.email.focus()
  },

  methods: {
    async submit() {
      if (!this.email || !this.password) {
        this.error = 'Renseignez votre adresse e-mail et votre mot de passe.'
        return
      }

      this.loading = true
      this.error = ''

      try {
        const user = await login(this.email, this.password)
        const redirect = this.$route.query.redirect
        this.$router.push(typeof redirect === 'string' && redirect.startsWith('/') ? redirect : homeFor(user.role))
      } catch (error) {
        // The API gives one message for any wrong pair, on purpose.
        this.error = error.status === 401 ? 'Adresse e-mail ou mot de passe incorrect.' : error.message
        this.password = ''
      } finally {
        this.loading = false
      }
    },
  },
}
</script>
