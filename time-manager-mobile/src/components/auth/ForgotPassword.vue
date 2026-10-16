<template>
  <details class="forgot" :open="open" @toggle="open = $event.target.open">
    <summary>{{ title || tr('Mot de passe oublié ?', 'Forgot your password?') }}</summary>
    <form v-if="step === 'email'" class="form-grid" @submit.prevent="sendCode">
      <p class="small muted">{{ tr('Un code à 8 chiffres vous sera envoyé par e-mail (valable 15 minutes).', 'An 8-digit code will be sent to you by e-mail (valid for 15 minutes).') }}</p>
      <label for="forgot-email">{{ tr('Adresse e-mail du compte', 'Account e-mail address') }}</label>
      <input id="forgot-email" v-model.trim="mail" type="email" autocomplete="username" maxlength="254" required />
      <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
      <button type="submit" class="btn-outline" :disabled="busy">{{ tr('Recevoir un code', 'Get a code') }}</button>
    </form>
    <form v-else class="form-grid" @submit.prevent="reset">
      <p class="notice-ok small" role="status">{{ tr('Si un compte correspond à {0}, un code vient d’être envoyé.', 'If an account matches {0}, a code has just been sent.').replace('{0}', mail) }}</p>
      <label for="forgot-code">{{ tr('Code reçu par e-mail', 'Code received by e-mail') }}</label>
      <input id="forgot-code" v-model.trim="code" inputmode="numeric" autocomplete="one-time-code" pattern="[0-9]{8}" maxlength="8" required />
      <label for="forgot-password">{{ tr('Nouveau mot de passe (8 à 128 caractères)', 'New password (8 to 128 characters)') }}</label>
      <PasswordInput id="forgot-password" v-model="password" autocomplete="new-password" />
      <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="alert">{{ message }}</p>
      <button type="submit" :disabled="busy">{{ tr('Changer mon mot de passe', 'Change my password') }}</button>
      <button type="button" class="btn-quiet small" :disabled="busy" @click="restart">{{ tr('Renvoyer un code', 'Send a new code') }}</button>
    </form>
  </details>
</template>

<script>
import { lang } from '@/i18n/index.js'
import { request } from '@/services/http.js'
import { authError } from '@/ui/authErrors.js'
import PasswordInput from '@/components/auth/PasswordInput.vue'

// « Mot de passe oublié ? » (backend, section 6 / contrat section 14) :
// 1. POST /auth/forgot-password {email}            → code à 8 chiffres envoyé par e-mail ;
// 2. POST /auth/reset-password {email, code, password} → mot de passe changé, puis connexion normale.
// La réponse de l'étape 1 est la même que le compte existe ou non (le serveur ne le révèle pas).
export default {
  name: 'ForgotPassword',
  components: { PasswordInput },
  props: { email: { type: String, default: '' }, title: { type: String, default: '' } },
  data() { return { open: false, step: 'email', mail: this.email, code: '', password: '', busy: false, message: '', ok: false } },
  watch: { email(value) { if (!this.mail) this.mail = value } },
  methods: {
    tr: (fr, en) => (lang.value === 'en' ? en : fr),
    async call(path, body, done) {
      this.busy = true
      this.message = ''
      try { await request(path, { method: 'POST', body }); done() } catch (error) {
        Object.assign(this, { ok: false, message: authError(error) })
      } finally { this.busy = false }
    },
    sendCode() {
      this.call('/auth/forgot-password', { email: this.mail.toLowerCase() }, () => { this.step = 'code' })
    },
    reset() {
      if (this.password.length < 8) { Object.assign(this, { ok: false, message: this.tr('Au moins 8 caractères.', 'At least 8 characters.') }); return }
      this.call('/auth/reset-password', { email: this.mail.toLowerCase(), code: this.code, password: this.password }, () => {
        Object.assign(this, { step: 'email', code: '', password: '', ok: true,
          message: this.tr('Mot de passe changé. Connectez-vous avec le nouveau.', 'Password changed. Sign in with the new one.') })
      })
    },
    restart() { Object.assign(this, { step: 'email', code: '', message: '' }) },
  },
}
</script>
