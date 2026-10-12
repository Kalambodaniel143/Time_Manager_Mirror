<template>
  <AuthLayout>
    <div v-if="submitted" class="auth-form">
      <h2 class="page-title">Demande envoyée</h2>
      <p class="lede">
        Votre adresse e-mail est vérifiée. Votre demande est maintenant en attente de validation
        par l’administrateur.
      </p>
      <p class="field-hint">
        Vous recevrez vos identifiants par e-mail lorsque votre demande sera acceptée.
      </p>
      <RouterLink class="btn btn-primary btn-login" :to="{ name: 'login' }">Retour à la connexion</RouterLink>
    </div>

    <form v-else-if="!verificationPending" class="auth-form" novalidate @submit.prevent="submit">
      <h2 class="page-title">Demander un accès</h2>
      <p class="lede">Remplissez vos informations personnelles. L’administrateur validera ensuite votre accès.</p>

      <label v-for="field in identityFields" :key="field.name" class="field">
        <span class="field-label">{{ field.label }}</span>
        <input v-model.trim="profile[field.name]" class="input" :class="{ 'has-error': shown(field.name) }" :type="field.type" :autocomplete="field.autocomplete" @blur="touched[field.name] = true" />
        <span v-if="shown(field.name)" class="field-error">{{ errors[field.name] }}</span>
      </label>

      <label class="field">
        <span class="field-label">Genre</span>
        <select v-model="profile.gender" class="input" :class="{ 'has-error': shown('gender') }" @blur="touched.gender = true">
          <option value="">Sélectionner</option>
          <option v-for="gender in genders" :key="gender.value" :value="gender.value">{{ gender.label }}</option>
        </select>
        <span v-if="shown('gender')" class="field-error">{{ errors.gender }}</span>
      </label>

      <label class="field">
        <span class="field-label">Date de naissance</span>
        <input v-model="profile.birth_date" class="input" :class="{ 'has-error': shown('birth_date') }" type="date" @blur="touched.birth_date = true" />
        <span v-if="shown('birth_date')" class="field-error">{{ errors.birth_date }}</span>
      </label>

      <label class="field">
        <span class="field-label">Lieu de naissance</span>
        <input v-model.trim="profile.birth_place" class="input" :class="{ 'has-error': shown('birth_place') }" autocomplete="address-level2" @blur="touched.birth_place = true" />
        <span v-if="shown('birth_place')" class="field-error">{{ errors.birth_place }}</span>
      </label>

      <p v-if="error" class="field-error" role="alert">{{ error }}</p>
      <button class="btn btn-primary btn-login" type="submit" :disabled="loading">
        <AppIcon name="check" />
        {{ loading ? 'Envoi…' : 'Recevoir le code de vérification' }}
      </button>
      <p class="switch">Déjà un compte ? <RouterLink class="link" :to="{ name: 'login' }">Se connecter</RouterLink></p>
    </form>

    <form v-else class="auth-form" novalidate @submit.prevent="verify">
      <h2 class="page-title">Vérifier votre e-mail</h2>
      <p class="lede">Un code à 6 chiffres a été envoyé à <strong>{{ profile.email }}</strong>.</p>
      <label class="field">
        <span class="field-label">Code de vérification</span>
        <input ref="code" v-model.trim="code" class="input" inputmode="numeric" autocomplete="one-time-code" maxlength="6" />
      </label>
      <p v-if="error" class="field-error" role="alert">{{ error }}</p>
      <button class="btn btn-primary btn-login" type="submit" :disabled="loading">
        <AppIcon name="check" />
        {{ loading ? 'Vérification…' : 'Valider mon adresse e-mail' }}
      </button>
      <button class="btn btn-secondary btn-login" type="button" :disabled="loading" @click="resend">Renvoyer le code</button>
      <p class="switch"><button class="link link-button" type="button" @click="verificationPending = false">Modifier les informations</button></p>
    </form>
  </AuthLayout>
</template>

<script>
import { RouterLink } from 'vue-router'
import AppIcon from './ui/AppIcon.vue'
import AuthLayout from './layout/AuthLayout.vue'
import { register, resendVerification, verifyEmail } from '../stores/auth'
import { GENDERS, emptyProfile, profileErrors, profilePayload } from '../utils/registration'

const FIELDS = Object.keys(emptyProfile())

export default {
  name: 'Registration',
  components: { AppIcon, AuthLayout, RouterLink },
  data() {
    return {
      profile: emptyProfile(),
      touched: Object.fromEntries(FIELDS.map((field) => [field, false])),
      error: '',
      loading: false,
      verificationPending: false,
      submitted: false,
      code: '',
      genders: GENDERS,
      identityFields: [
        { name: 'first_name', label: 'Prénom', type: 'text', autocomplete: 'given-name' },
        { name: 'last_name', label: 'Nom', type: 'text', autocomplete: 'family-name' },
        { name: 'email', label: 'Adresse e-mail', type: 'email', autocomplete: 'email' },
      ],
    }
  },
  computed: {
    errors() { return profileErrors(this.profile, true) },
  },
  mounted() { this.$el.querySelector('input')?.focus() },
  methods: {
    shown(field) { return this.touched[field] && this.errors[field] },
    async submit() {
      FIELDS.forEach((field) => { this.touched[field] = true })
      if (Object.keys(this.errors).length) return
      this.loading = true
      this.error = ''
      try {
        await register(profilePayload(this.profile, true))
        this.verificationPending = true
        this.$nextTick(() => this.$refs.code?.focus())
      } catch (error) {
        this.error = error.message
      } finally { this.loading = false }
    },
    async verify() {
      if (!/^\d{6}$/.test(this.code)) { this.error = 'Saisissez le code à 6 chiffres reçu par e-mail.'; return }
      this.loading = true
      this.error = ''
      try {
        await verifyEmail(this.profile.email, this.code)
        this.submitted = true
      } catch (error) {
        this.error = error.message
      } finally { this.loading = false }
    },
    async resend() {
      this.loading = true
      this.error = ''
      try { await resendVerification(this.profile.email) }
      catch (error) { this.error = error.message }
      finally { this.loading = false }
    },
  },
}
</script>
