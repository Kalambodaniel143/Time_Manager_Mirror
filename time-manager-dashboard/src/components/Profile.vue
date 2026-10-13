<template>
  <div class="profile">
    <PageHeader :eyebrow="$t(&quot;Votre identité, votre affichage et votre confidentialité&quot;)" :title="$t(&quot;Mon compte&quot;)" />

    <section class="card identity-summary"><div class="avatar">{{ initials }}</div><div><h2>{{ displayName }}</h2><p class="muted">{{ $t(roleLabel) }} · {{ profile.email }}</p><p v-if="organization" class="muted">{{ organization.name }}</p></div></section>
    <div class="layout">
      <section class="card section">
        <h2 class="card-title">{{ $t("Préférences d’affichage") }}</h2><LanguageSelect />
        <label v-for="option in themes" :key="option.value" class="theme-option" :class="{ selected: theme === option.value }"><span><input type="radio" name="account-theme" :value="option.value" :checked="theme === option.value" @change="$emit('update:theme', option.value)" /> {{ $t(option.label) }}</span><span v-if="theme === option.value" class="field-hint">{{ $t("Sélectionné") }}</span></label>
        <label class="strong-option"><input v-model="strongText" type="checkbox" @change="saveStrongText" /> {{ $t("Utiliser des textes renforcés") }}</label>
        <button class="btn btn-outline" type="button" @click="$emit('tour')">{{ $t("Revoir la prise en main") }}</button>
      </section>
      <section v-if="!demo" class="card section page-stack"><h2 class="card-title">{{ $t("Lecture vocale") }}</h2><p>{{ $t("Écoutez les textes et les étapes du guide avec une voix de votre navigateur.") }}</p><label><input v-model="voice.enabled" type="checkbox" /> {{ $t("Afficher les commandes de lecture") }}</label><label class="field"><span class="field-label">{{ $t("Vitesse") }}</span><input v-model.number="voice.rate" class="input" type="range" min="0.5" max="2" step="0.1" /></label><label class="field"><span class="field-label">{{ $t("Voix") }}</span><select v-model="voice.name" class="input"><option value="">{{ $t("Voix par défaut de la langue choisie") }}</option><option v-for="item in voices" :key="item.name" :value="item.name">{{ item.name }} · {{ item.lang }}</option></select></label><button class="btn btn-primary" @click="saveVoice">{{ $t("Enregistrer la lecture vocale") }}</button><button class="btn btn-outline" @click="testVoice">{{ $t("Écouter un exemple") }}</button><p v-if="preferenceError" class="field-error" role="alert">{{ $t(preferenceError) }}</p></section>
      <TransparencyPanel />
      <section v-if="organization" class="card section"><h2 class="card-title">{{ $t("Votre compte d’organisation") }}</h2><p>{{ $t("Votre compte est rattaché à Gotham City. Le super administrateur gère les demandes d’adhésion et les rôles depuis « Administration Gotham ».") }}</p></section>
      <form v-if="!demo" class="card section" novalidate @submit.prevent="saveProfile">
        <h2 class="card-title">{{ $t("Identité") }}</h2>
        <p class="card-subtitle">{{ $t("Votre rôle :") }} <strong>{{ $t(roleLabel) }}</strong>{{ $t(". Seule l’administration peut le changer.") }}</p>

        <label class="field"><span class="field-label">{{ $t("Prénom") }}</span><input v-model.trim="profile.first_name" class="input" autocomplete="given-name" maxlength="100" /><span v-if="profileErrors.first_name" class="field-error">{{ $t(profileErrors.first_name) }}</span></label>
        <label class="field"><span class="field-label">{{ $t("Nom") }}</span><input v-model.trim="profile.last_name" class="input" autocomplete="family-name" maxlength="100" /><span v-if="profileErrors.last_name" class="field-error">{{ $t(profileErrors.last_name) }}</span></label>

        <label class="field">
          <span class="field-label">{{ $t("Identifiant") }}</span>
          <input v-model.trim="profile.username" class="input" :class="{ 'has-error': profileErrors.username }" autocomplete="username" />
          <span v-if="profileErrors.username" class="field-error">{{ $t(profileErrors.username) }}</span>
        </label>

        <label class="field">
          <span class="field-label">{{ $t("Adresse e-mail") }}</span>
          <input v-model.trim="profile.email" class="input" :class="{ 'has-error': profileErrors.email }" type="email" autocomplete="email" />
          <span v-if="profileErrors.email" class="field-error">{{ $t(profileErrors.email) }}</span>
        </label>

        <p v-if="profileError" class="field-error" role="alert">{{ $t(profileError) }}</p>

        <div>
          <button class="btn btn-primary btn-sm" type="submit" :disabled="savingProfile || hasProfileErrors">{{ $t("Enregistrer") }}</button>
        </div>
      </form>

      <form v-if="!demo" class="card section" novalidate @submit.prevent="savePassword">
        <h2 class="card-title">{{ $t("Mot de passe") }}</h2>
        <p class="card-subtitle">{{ $t("Remplacez le mot de passe fourni par votre administrateur par un mot de passe personnel. Votre mot de passe actuel est nécessaire. Après le changement, reconnectez-vous sur vos appareils ; un email vous informera de la modification.") }}</p>

        <label class="field">
          <span class="field-label">{{ $t("Mot de passe actuel") }}</span>
          <input v-model="password.current" class="input" type="password" autocomplete="current-password" />
        </label>

        <label class="field">
          <span class="field-label">{{ $t("Nouveau mot de passe") }}</span>
          <input v-model="password.next" class="input" type="password" autocomplete="new-password" />
          <PasswordHint />
        </label>

        <label class="field">
          <span class="field-label">{{ $t("Confirmation") }}</span>
          <input v-model="password.confirmation" class="input" type="password" autocomplete="new-password" />
        </label>

        <p v-if="passwordError" class="field-error" role="alert">{{ $t(passwordError) }}</p>

        <div>
          <button class="btn btn-primary btn-sm" type="submit" :disabled="savingPassword">{{ $t("Changer le mot de passe") }}</button>
        </div>
      </form>
    </div>
    <section class="card section support"><h2 class="card-title">{{ $t("Besoin d’un accompagnement ?") }}</h2><p>{{ $t("Un téléphone ou un appareil partagé suffit. Si vous ne pouvez pas utiliser l’application seul, votre responsable peut vous accompagner pour enregistrer vos horaires réels.") }}</p><p class="field-hint">{{ $t("Un oubli ? Complétez votre départ. Une heure déjà enregistrée est incorrecte ? Proposez une correction depuis « Mes heures ». Une semaine validée doit être rouverte par votre responsable.") }}</p></section>
    <section class="card section deletion-section"><div><h2 class="card-title">{{ $t("Supprimer mon compte") }}</h2><p>{{ $t("Cette action supprime votre compte, vos pointages et vos périodes de travail. Vous serez déconnecté et ne pourrez plus utiliser ces identifiants.") }}</p><p v-if="isSuperAdministrator" class="field-hint">{{ $t("Le dernier super administrateur doit transférer ses responsabilités avant de pouvoir supprimer son compte.") }}</p></div><button class="btn btn-danger" type="button" @click="openDeletion">{{ $t("Supprimer mon compte") }}</button></section>
    <ModalDialog v-if="deletionOpen" :title="$t(&quot;Confirmer la suppression de mon compte&quot;)" id="account-deletion-title" :busy="deleting" @close="closeDeletion"><p>{{ $t("Vous allez supprimer le compte") }} <strong>{{ profile.email }}</strong>{{ $t(". Cette action est définitive.") }}</p><form class="page-stack" novalidate @submit.prevent="deleteAccount"><label class="field"><span class="field-label">{{ $t("Mot de passe actuel pour confirmer") }}</span><input v-model="deletionPassword" class="input" type="password" autocomplete="current-password" :disabled="deleting" required /></label><label class="deletion-confirmation"><input v-model="deletionConfirmed" type="checkbox" :disabled="deleting" /> {{ $t("Je confirme la suppression définitive de mon compte.") }}</label><p v-if="deletionError" class="field-error" role="alert">{{ $t(deletionError) }}</p><div class="deletion-actions"><button class="btn btn-outline" type="button" :disabled="deleting" @click="closeDeletion">{{ $t("Annuler") }}</button><button class="btn btn-danger" type="submit" :disabled="deleting || !deletionConfirmed || !deletionPassword">{{ $t(deleting ? 'Suppression…' : 'Supprimer définitivement') }}</button></div></form></ModalDialog>
    <section class="card section logout-section"><div><h2 class="card-title">{{ $t("Quitter votre session") }}</h2><p class="muted">{{ $t("Déconnectez-vous après utilisation sur un appareil partagé.") }}</p></div><button class="btn btn-primary" type="button" @click="$emit('logout')">{{ $t("Se déconnecter") }}</button></section>
  </div>
</template>

<script>
import LanguageSelect from './ui/LanguageSelect.vue'
import ModalDialog from './ui/ModalDialog.vue'
import PasswordHint from './auth/PasswordHint.vue'
import { deleteOwnAccount } from '../services/accountService'
import PageHeader from './ui/PageHeader.vue'
import TransparencyPanel from './employee/TransparencyPanel.vue'
import { readStrongText, writeStrongText } from '../utils/session'
import * as userService from '../services/userService'
import { auth, ROLE_LABELS, setUser } from '../stores/auth'
import { EMAIL_PATTERN, PASSWORD_MIN_LENGTH, displayName } from '../utils/people'
import { workforce, savePreferences, loadContext } from '../services/workforceService'
import { speechSupported, readAloud, stopReading } from '../utils/speech'
import { isDemoData } from '../services/orgService'
import { notify } from '../utils/toast'
import { nameError, passwordError as validatePassword } from '../utils/registration'

export default {
  name: 'Profile',

  components: { LanguageSelect, PasswordHint, ModalDialog, PageHeader, TransparencyPanel },

  props: { theme: { type: String, required: true } },
  emits: ['update:theme', 'logout', 'tour', 'deleted'],

  data() {
    return {
      voices: [], voice: { enabled: Boolean(workforce.preferences.speech_enabled), rate: workforce.preferences.speech_rate || 1, name: workforce.preferences.speech_voice || '' }, preferenceError: '',
      deletionOpen: false,
      deletionPassword: '',
      deletionConfirmed: false,
      deletionError: '',
      deleting: false,
      deletionDisposed: false,
      strongText: readStrongText(),
      themes: [{ value: 'light', label: 'Clair' }, { value: 'night', label: 'Nuit' }, { value: 'contrast', label: 'Contraste élevé' }],
      profile: { username: auth.user.username, email: auth.user.email, first_name: auth.user.first_name || '', last_name: auth.user.last_name || '' },
      password: { current: '', next: '', confirmation: '' },
      minLength: PASSWORD_MIN_LENGTH,
      savingProfile: false,
      savingPassword: false,
      profileError: '',
      passwordError: '',
    }
  },

  computed: {
    demo: isDemoData,
    currentUserId() { return auth.user?.id },
    isSuperAdministrator() { return auth.user?.role === 'administrator' },
    organization() { return auth.organization || null },
    displayName() { return displayName(auth.user) },
    initials() { return this.displayName.split(/[ ._-]+/).filter(Boolean).map(part => part[0]).join('').slice(0, 2).toUpperCase() },
    roleLabel() {
      return ROLE_LABELS[auth.user?.role] || auth.user?.role || ''
    },

    profileErrors() {
      const errors = {}
      if (!this.profile.username) errors.username = 'Un identifiant est nécessaire.'
      if (!EMAIL_PATTERN.test(this.profile.email)) errors.email = 'Adresse invalide (ex. nom@domaine.fr).'
      if (this.organization && !this.profile.first_name) errors.first_name = 'Le prénom est nécessaire pour un compte d’organisation.'
      if (this.organization && !this.profile.last_name) errors.last_name = 'Le nom est nécessaire pour un compte d’organisation.'
      for (const key of ['first_name', 'last_name']) { if (nameError(this.profile[key])) errors[key] = nameError(this.profile[key]) }
      return errors
    },

    hasProfileErrors() {
      return Object.keys(this.profileErrors).length > 0
    },
  },

  watch: {
    currentUserId(id, previous) {
      if (id === previous) return
      this.deletionOpen = false; this.deletionPassword = ''; this.deletionConfirmed = false
      this.password = { current: '', next: '', confirmation: '' }
      if (auth.user) this.profile = { username: auth.user.username, email: auth.user.email, first_name: auth.user.first_name || '', last_name: auth.user.last_name || '' }
    },
  },
  async mounted() { this.refreshVoices(); if (speechSupported()) window.speechSynthesis.addEventListener('voiceschanged', this.refreshVoices); if (!this.demo) { try { const ctx = await loadContext(); if (!this.deletionDisposed) { this.voice = { enabled: ctx.preferences.speech_enabled, rate: ctx.preferences.speech_rate, name: ctx.preferences.speech_voice }; this.strongText = ctx.preferences.strong_text } } catch (error) { this.preferenceError = error.message } } },
  beforeUnmount() { this.deletionDisposed = true; this.deletionPassword = ''; stopReading(); if (speechSupported()) window.speechSynthesis.removeEventListener('voiceschanged', this.refreshVoices) },
  methods: {
    openDeletion() { this.deletionPassword = ''; this.deletionConfirmed = false; this.deletionError = ''; this.deletionOpen = true },
    closeDeletion() { if (this.deleting) return; this.deletionOpen = false; this.deletionPassword = ''; this.deletionConfirmed = false; this.deletionError = '' },
    async deleteAccount() {
      if (this.deleting) return
      if (!this.deletionConfirmed || !this.deletionPassword) { this.deletionError = 'Confirmez la suppression et saisissez votre mot de passe actuel.'; return }
      const userId = auth.user?.id
      this.deleting = true; this.deletionError = ''
      try {
        await deleteOwnAccount(this.deletionPassword)
        this.deletionPassword = ''; this.password = { current: '', next: '', confirmation: '' }; this.deletionOpen = false
        if (!this.deletionDisposed && auth.user?.id === userId) this.$emit('deleted')
      } catch (error) {
        this.deletionPassword = ''
        if (this.deletionDisposed || auth.user?.id !== userId) return
        this.deletionError = error.status === 409 && /last administrator|dernier super administrateur/i.test(error.message) ? 'Le dernier super administrateur ne peut pas supprimer son compte. Transférez d’abord ses responsabilités.' : error.payload?.errors?.current_password ? 'Mot de passe actuel incorrect.' : error.message
      } finally { this.deleting = false }
    },
    refreshVoices() { this.voices = speechSupported() ? window.speechSynthesis.getVoices() : [] },
    async saveVoice() { this.preferenceError = ''; try { await savePreferences({ speech_enabled: this.voice.enabled, speech_rate: this.voice.rate, speech_voice: this.voice.name }) } catch (error) { this.preferenceError = error.message } },
    testVoice() { if (!speechSupported()) { this.preferenceError = 'La lecture vocale n’est pas disponible dans ce navigateur.'; return }; readAloud(this.$t('Bienvenue dans Time Manager. Vous pouvez écouter vos horaires et le guide de prise en main.'), { speech_rate: this.voice.rate, speech_voice: this.voice.name }) },
    async saveStrongText() { writeStrongText(this.strongText); if (!this.demo) { try { await savePreferences({ strong_text: this.strongText }) } catch (error) { this.preferenceError = error.message } } },
    async saveProfile() {
      if (this.hasProfileErrors || this.savingProfile) return
      const userId = auth.user.id
      this.savingProfile = true
      this.profileError = ''

      try {
        const user = await userService.updateUser(userId, { ...this.profile })
        if (!this.deletionDisposed && auth.user?.id === userId) { setUser(user); notify('Profil mis à jour.') }
      } catch (error) {
        this.profileError = error.message
      } finally {
        this.savingProfile = false
      }
    },

    async savePassword() {
      if (this.savingPassword) return
      if (!this.password.current) { this.passwordError = 'Saisissez votre mot de passe actuel pour autoriser ce changement.'; return }
      if (validatePassword(this.password.next)) {
        this.passwordError = validatePassword(this.password.next)
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
        this.$emit('logout')
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
.deletion-section { margin-top: 24px; border-color: var(--danger); align-items: flex-start; }
.deletion-section p { margin-top: 8px; font-size: 14px; }
.deletion-section h2 { color: var(--danger); }
.deletion-confirmation { display: flex; align-items: flex-start; gap: 10px; font-size: 14px; }
.deletion-confirmation input { margin-top: 4px; }
.deletion-actions { display: flex; gap: 10px; justify-content: flex-end; flex-wrap: wrap; }
@media (max-width: 760px) { .deletion-section > button { width: 100%; } .deletion-actions .btn { flex: 1; } }
</style>
