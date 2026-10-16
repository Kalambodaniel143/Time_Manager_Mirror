<template>
  <form class="page-stack" novalidate :aria-busy="busy" @submit.prevent="sent ? reset() : send()">
    <h2 class="page-title">{{ $t("Mot de passe oublié") }}</h2>
    <p class="lede">{{ $t("Recevez un code à votre adresse email pour choisir un nouveau mot de passe.") }}</p>
    <label class="field"><span class="field-label">{{ $t("Adresse email du compte") }}</span><input v-model.trim="email" class="input" type="email" autocomplete="username" required :readonly="sent" /></label>
    <p v-if="message" class="info-note" role="status">{{ $t(message) }}</p>
    <template v-if="sent && !completed">
      <label class="field"><span class="field-label">{{ $t("Code reçu par email") }}</span><input v-model.trim="code" class="input num" inputmode="numeric" autocomplete="one-time-code" minlength="8" maxlength="8" required /><span class="field-hint">{{ $t("8 chiffres, valables 15 minutes. Seul le dernier code reçu fonctionne.") }}</span></label>
      <label class="field"><span class="field-label">{{ $t("Nouveau mot de passe") }}</span><input v-model="password" class="input" type="password" autocomplete="new-password" required minlength="8" maxlength="128" /></label>
      <PasswordHint />
      <label class="field"><span class="field-label">{{ $t("Confirmer le nouveau mot de passe") }}</span><input v-model="confirmation" class="input" type="password" autocomplete="new-password" required /></label>
    </template>
    <p v-if="error" class="field-error" role="alert">{{ $t(error) }}</p>
    <button v-if="!completed" class="btn btn-primary" :disabled="busy" type="submit">{{ $t(busy ? 'Traitement…' : sent ? 'Réinitialiser le mot de passe' : 'Recevoir un code') }}</button>
    <button v-if="sent && !completed" class="btn btn-outline" :disabled="busy" type="button" @click="send">{{ $t("Recevoir un nouveau code") }}</button>
    <button class="link" :disabled="busy" type="button" @click="$emit('close', email)">{{ $t("Retour à la connexion") }}</button>
  </form>
</template>
<script>
import PasswordHint from './PasswordHint.vue'
import { passwordError } from '../../utils/registration'
import { requestPasswordRecovery, resetPassword } from '../../services/passwordRecoveryService'
export default {
  name: 'PasswordRecovery', components: { PasswordHint }, props: { initialEmail: { type: String, default: '' } }, emits: ['close'],
  data() { return { email: this.initialEmail, code: '', password: '', confirmation: '', sent: false, completed: false, busy: false, message: '', error: '' } },
  beforeUnmount() { this.password = ''; this.confirmation = ''; this.code = '' },
  methods: {
    async send() {
      if (this.busy) return
      this.error = ''; this.message = ''
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email)) { this.error = 'Saisissez une adresse email valide, par exemple nom@domaine.fr.'; return }
      this.busy = true
      try { const result = await requestPasswordRecovery(this.email); this.sent = true; this.code = ''; this.message = result.message }
      catch (error) { this.error = error.message }
      finally { this.busy = false }
    },
    async reset() {
      if (this.busy || this.completed) return
      this.error = passwordError(this.password)
      if (this.error) return
      if (!/^\d{8}$/.test(this.code)) { this.error = 'Recopiez les huit chiffres du dernier code reçu par email.'; return }
      if (this.password !== this.confirmation) { this.error = 'Les deux nouveaux mots de passe diffèrent.'; return }
      this.busy = true
      try { const result = await resetPassword(this.email, this.code, this.password); this.completed = true; this.message = result.message; this.password = ''; this.confirmation = ''; this.code = '' }
      catch (error) { this.error = error.message }
      finally { this.busy = false }
    },
  },
}
</script>
