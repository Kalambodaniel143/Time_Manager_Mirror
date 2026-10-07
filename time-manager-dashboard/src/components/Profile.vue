<template>
  <div class="profile">
    <PageHeader eyebrow="Votre identité, votre affichage et votre confidentialité" title="Mon compte" />

    <section class="card identity-summary"><div class="avatar">{{ initials }}</div><div><h2>{{ displayName }}</h2><p class="muted">{{ roleLabel }} · {{ profile.email }}</p><p v-if="organization" class="muted">{{ organization.name }}</p></div></section>
    <div class="layout">
      <section class="card section">
        <h2 class="card-title">Préférences d’affichage</h2>
        <label v-for="option in themes" :key="option.value" class="theme-option" :class="{ selected: theme === option.value }"><span><input type="radio" name="account-theme" :value="option.value" :checked="theme === option.value" @change="$emit('update:theme', option.value)" /> {{ option.label }}</span><span v-if="theme === option.value" class="field-hint">Sélectionné</span></label>
        <label class="strong-option"><input v-model="strongText" type="checkbox" @change="saveStrongText" /> Utiliser des textes renforcés</label>
        <button class="btn btn-outline" type="button" @click="$emit('tour')">Revoir la prise en main</button>
      </section>
      <TransparencyPanel />
      <section v-if="organization" class="card section"><h2 class="card-title">Votre compte d’organisation</h2><p>Votre identité est celle du compte accepté par votre administration. Dans cette démonstration, les identifiants se gèrent depuis « Mon organisation ».</p></section>
      <form v-if="!organization" class="card section" novalidate @submit.prevent="saveProfile">
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

      <form v-if="!organization" class="card section" novalidate @submit.prevent="savePassword">
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
    <section class="card section support"><h2 class="card-title">Besoin d’un accompagnement ?</h2><p>Un téléphone ou un appareil partagé suffit. Si vous ne pouvez pas utiliser l’application seul, votre responsable peut vous accompagner pour enregistrer vos horaires réels.</p><p class="field-hint">Un oubli ? Complétez votre départ. Une heure déjà enregistrée est incorrecte ? Proposez une correction depuis « Mes heures ».</p></section>
    <section class="card section logout-section"><div><h2 class="card-title">Quitter votre session</h2><p class="muted">Déconnectez-vous après utilisation sur un appareil partagé.</p></div><button class="btn btn-primary" type="button" @click="$emit('logout')">Se déconnecter</button></section>
  </div>
</template>

<script>
import PageHeader from './ui/PageHeader.vue'
import TransparencyPanel from './employee/TransparencyPanel.vue'
import { readStrongText, writeStrongText } from '../utils/session'
import * as userService from '../services/userService'
import { auth, ROLE_LABELS, setUser } from '../stores/auth'
import { EMAIL_PATTERN, PASSWORD_MIN_LENGTH } from '../utils/people'
import { notify } from '../utils/toast'

export default {
  name: 'Profile',

  components: { PageHeader, TransparencyPanel },

  props: { theme: { type: String, required: true } },
  emits: ['update:theme', 'logout', 'tour'],

  data() {
    return {
      strongText: readStrongText(),
      themes: [{ value: 'light', label: 'Clair' }, { value: 'night', label: 'Nuit' }, { value: 'contrast', label: 'Contraste élevé' }],
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
    organization() { return auth.organizationSession?.organization || null },
    displayName() { return auth.organizationSession ? `${auth.user.first_name} ${auth.user.last_name}` : auth.user.username },
    initials() { return this.displayName.split(/[ ._-]+/).filter(Boolean).map(part => part[0]).join('').slice(0, 2).toUpperCase() },
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
    saveStrongText() { writeStrongText(this.strongText) },
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
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 24px;
  align-items: start;
}

.section {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 24px;
}
.identity-summary { display: flex; gap: 18px; align-items: center; padding: 24px; margin-bottom: 24px; }
.avatar { display: grid; place-items: center; width: 48px; height: 48px; border-radius: 50%; background: var(--brand-soft); color: var(--title); font-weight: 700; }
.theme-option { display: flex; align-items: center; justify-content: space-between; gap: 12px; border: 1px solid var(--border); border-radius: 6px; padding: 10px 12px; cursor: pointer; }
.theme-option.selected { border-color: var(--brand); background: var(--brand-soft); }
.theme-option input { accent-color: var(--brand); }
.strong-option { display: flex; gap: 8px; align-items: center; }
.support { margin-top: 24px; }
.logout-section { flex-direction: row; align-items: center; justify-content: space-between; margin-top: 24px; }
@media (max-width: 760px) { .layout { grid-template-columns: 1fr; } .logout-section { flex-direction: column; align-items: stretch; } }
</style>
