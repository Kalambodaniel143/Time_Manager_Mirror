<template>
  <div class="login">
    <section class="intro">
      <span class="deco deco-a" aria-hidden="true"></span>
      <span class="deco deco-b" aria-hidden="true"></span>
      <div class="intro-body">
        <h1 class="intro-title">Time Manager</h1>
        <p class="intro-eyebrow">Votre organisation, vos équipes</p>
        <ul class="intro-list">
          <li v-for="point in points" :key="point.icon"><AppIcon :name="point.icon" />{{ point.text }}</li>
        </ul>
      </div>
      <div class="pixels" aria-hidden="true"><span v-for="(tone, index) in pixels" :key="index" :class="`pixel-${tone}`"></span></div>
    </section>

    <main class="panel">
      <div class="form">
        <nav class="access-nav" aria-label="Accès à Time Manager">
          <button v-for="option in modes" :key="option.value" class="access-choice" :class="{ active: mode === option.value }" type="button" :aria-pressed="mode === option.value" :disabled="busy" @click="changeMode(option.value)">
            <AppIcon :name="option.icon" />{{ option.label }}
          </button>
        </nav>

        <div v-if="receipt" class="card receipt" role="status">
          <span class="pill" :class="statusClass">{{ statusLabel }}</span>
          <h2 class="card-title">{{ receipt.organization_name }}</h2>
          <p v-if="receipt.status === 'pending'">Votre demande attend la décision de l’admin. Aucun compte n’est encore actif.</p>
          <p v-else-if="receipt.status === 'approved'">Votre demande a été acceptée. L’admin vous fournit votre mot de passe ; utilisez votre email pour vous connecter.</p>
          <p v-else>Votre demande a été refusée. {{ receipt.rejection_reason }}</p>
          <label class="field"><span class="field-label">Référence de suivi à conserver</span><input class="input num" :value="receipt.reference" readonly /></label>
          <div class="actions"><button class="btn btn-outline" type="button" :disabled="busy" @click="refreshStatus">Actualiser le statut</button><button class="btn btn-quiet" type="button" @click="dismissReceipt">Fermer</button></div>
        </div>

        <form v-if="mode === 'login'" novalidate :aria-busy="busy" @submit.prevent="submitLogin">
          <h2 class="page-title">Connexion</h2>
          <p class="lede">Votre email et le mot de passe fourni par votre admin vous donnent accès à votre organisation.</p>
          <label class="field"><span class="field-label">Adresse email</span><input v-model.trim="email" class="input" type="email" autocomplete="username" required /></label>
          <label class="field"><span class="field-label">Mot de passe</span><span class="password-control"><input v-model="password" class="input" :type="showLoginPassword ? 'text' : 'password'" autocomplete="current-password" required /><button class="password-toggle" type="button" :aria-label="showLoginPassword ? 'Masquer le mot de passe' : 'Afficher le mot de passe'" :aria-pressed="showLoginPassword" @click="showLoginPassword = !showLoginPassword"><AppIcon :name="showLoginPassword ? 'eye-off' : 'eye'" /></button></span></label>
          <p v-if="error" class="field-error" role="alert">{{ error }}</p>
          <button class="btn btn-primary btn-login" type="submit" :disabled="busy"><AppIcon name="login" />{{ busy ? 'Connexion…' : 'Se connecter' }}</button>
          <p class="field-hint">Demande en attente ? Utilisez « Suivre ma demande » ci-dessous.</p>
        </form>

        <form v-else-if="mode === 'create' || mode === 'join'" novalidate :aria-busy="busy" @submit.prevent="submitRegistration">
          <div><p class="eyebrow">{{ mode === 'create' ? 'Un nouvel espace' : 'Votre équipe vous attend' }}</p><h2 class="page-title">{{ mode === 'create' ? 'Créer une organisation' : 'Rejoindre une organisation' }}</h2></div>
          <p class="lede">{{ mode === 'create' ? 'Vous devenez l’admin de votre organisation. Vous pourrez accepter les demandes et nommer les managers.' : 'L’admin examine votre demande. Après acceptation, vous rejoignez l’organisation en tant qu’employé.' }}</p>
          <label class="field">
            <span id="organization-label" class="field-label">Nom de l’organisation</span>
            <input v-model.trim="organizationName" aria-labelledby="organization-label" class="input" autocomplete="organization" maxlength="100" required :aria-invalid="Boolean(errors.organization_name || errors.name)" aria-describedby="organization-error" @input="organizationChanged" />
            <span v-if="errors.organization_name || errors.name" id="organization-error" class="field-error">{{ errors.organization_name || errors.name }}</span>
          </label>
          <div v-if="mode === 'join'" class="organization-check">
            <button class="btn btn-outline btn-sm" type="button" :disabled="busy || checking || !organizationName" @click="verifyOrganization">{{ checking ? 'Vérification…' : 'Vérifier l’organisation' }}</button>
            <span v-if="organization" class="pill pill-ok"><AppIcon name="check" />{{ organization.name }}</span>
          </div>
          <ProfileFields v-model="profile" :errors="errors" :personal-details="mode === 'join'" />
          <template v-if="mode === 'create'">
            <label class="field"><span id="admin-password-label" class="field-label">Votre mot de passe admin</span><input v-model="password" aria-labelledby="admin-password-label" class="input" type="password" autocomplete="new-password" minlength="8" maxlength="128" required :aria-invalid="Boolean(errors.password)" aria-describedby="password-hint" /><span id="password-hint" :class="errors.password ? 'field-error' : 'field-hint'">{{ errors.password || 'Entre 8 et 128 caractères.' }}</span></label>
            <label class="field"><span class="field-label">Confirmer le mot de passe</span><input v-model="passwordConfirmation" class="input" type="password" autocomplete="new-password" required :aria-invalid="Boolean(errors.password_confirmation)" /><span v-if="errors.password_confirmation" class="field-error">{{ errors.password_confirmation }}</span></label>
          </template>
          <InfoNote v-else title="Le mot de passe vient de votre admin" flat>Vous n’avez pas de mot de passe à choisir ici. Si votre demande est acceptée, l’admin définit votre mot de passe et vous transmet vos identifiants.</InfoNote>
          <p v-if="error" class="field-error" role="alert">{{ error }}</p>
          <button class="btn btn-primary btn-login" type="submit" :disabled="busy || checking">{{ busy ? 'Enregistrement…' : mode === 'create' ? 'Créer mon organisation' : 'Envoyer ma demande' }}</button>
        </form>

        <form v-else novalidate :aria-busy="busy" @submit.prevent="refreshStatus">
          <h2 class="page-title">Suivre ma demande</h2>
          <p class="lede">Saisissez la référence reçue lors de votre demande d’adhésion.</p>
          <label class="field"><span class="field-label">Référence de suivi</span><input v-model.trim="reference" class="input" autocomplete="off" required /></label>
          <p v-if="error" class="field-error" role="alert">{{ error }}</p>
          <button class="btn btn-primary" type="submit" :disabled="busy">{{ busy ? 'Recherche…' : 'Consulter le statut' }}</button>
        </form>

        <button v-if="mode !== 'status'" class="link follow-link" type="button" :disabled="busy" @click="changeMode('status')">Suivre ma demande</button>
        <fieldset class="themes"><legend class="field-label">Choisissez votre affichage</legend><div class="theme-grid">
          <button v-for="option in themes" :key="option.value" class="theme-card" :class="{ 'is-active': option.value === theme }" type="button" :aria-pressed="option.value === theme" @click="$emit('update:theme', option.value)">
            <span class="swatch" aria-hidden="true"><span v-for="color in option.colors" :key="color" :style="{ background: color }"></span></span><span class="theme-name">{{ option.label }}</span><span class="theme-text">{{ option.text }}</span>
          </button>
        </div></fieldset>
        <p v-if="mock" class="field-hint">Simulation locale : les comptes et demandes restent dans ce navigateur. Aucun email n’est envoyé.</p>
      </div>
    </main>
  </div>
</template>

<script>
import AppIcon from '../components/ui/AppIcon.vue'
import InfoNote from '../components/ui/InfoNote.vue'
import ProfileFields from '../components/auth/ProfileFields.vue'
import { AUTH_USE_MOCK, createOrganization, getRequestStatus, joinOrganization, loginAccount, lookupOrganization } from '../services/organizationService'
import { emptyProfile, errorFields, organizationError, passwordError, profileErrors, profilePayload } from '../utils/registration'
import { readJson, writeJson } from '../utils/session'

const THEMES = [
  { value: 'light', label: 'Clair', text: 'Pour le bureau et la journée.', colors: ['#24584f', '#f7f6f2', '#e4eee8'] },
  { value: 'night', label: 'Nuit', text: 'Moins d’éblouissement.', colors: ['#203f33', '#121b17', '#a7d5c2'] },
  { value: 'contrast', label: 'Contraste élevé', text: 'Textes renforcés.', colors: ['#123c2e', '#ffffff', '#000000'] },
]
const RECEIPT_KEY = 'tm-last-join-receipt'

export default {
  name: 'LoginScreen',
  components: { AppIcon, InfoNote, ProfileFields },
  props: { theme: { type: String, required: true } },
  emits: ['login', 'update:theme'],
  data() {
    return {
      showLoginPassword: false, mode: 'login', email: '', password: '', passwordConfirmation: '', organizationName: '', organization: null,
      profile: emptyProfile(), errors: {}, error: '', busy: false, checking: false, lookupVersion: 0,
      receipt: null, reference: readJson(RECEIPT_KEY, null)?.reference || '', mock: AUTH_USE_MOCK,
      themes: THEMES,
      modes: [{ value: 'login', label: 'Connexion', icon: 'login' }, { value: 'create', label: 'Créer une organisation', icon: 'shield' }, { value: 'join', label: 'Rejoindre', icon: 'users' }],
      points: [{ icon: 'users', text: 'Créez votre organisation ou rejoignez votre équipe.' }, { icon: 'shield', text: 'Votre admin accepte les demandes et définit les accès.' }, { icon: 'clock', text: 'Retrouvez vos heures, votre planning et votre équipe.' }],
      pixels: 'llllddllllllolllddllo'.split('').map((code) => ({ l: 'light', d: 'dark', o: 'orange' })[code]),
    }
  },
  computed: {
    statusLabel() { return { pending: 'En attente', approved: 'Acceptée', rejected: 'Refusée' }[this.receipt?.status] || '' },
    statusClass() { return { pending: 'pill-warn', approved: 'pill-ok', rejected: 'pill-danger' }[this.receipt?.status] || '' },
  },
  methods: {
    changeMode(mode) {
      this.mode = mode
      this.error = ''
      this.errors = {}
      this.password = ''
      this.passwordConfirmation = ''
    },
    organizationChanged() { this.organization = null; this.lookupVersion += 1; this.checking = false; this.errors = { ...this.errors, organization_name: '', name: '' } },
    async verifyOrganization() {
      const message = organizationError(this.organizationName)
      if (message) { this.errors = { ...this.errors, organization_name: message }; return false }
      const version = ++this.lookupVersion
      this.checking = true
      this.organization = null
      try {
        const found = await lookupOrganization(this.organizationName)
        if (version !== this.lookupVersion) return false
        this.organization = found
        this.errors = { ...this.errors, organization_name: '' }
        return true
      } catch (error) {
        if (version === this.lookupVersion) this.errors = { ...this.errors, organization_name: error.message }
        return false
      } finally { if (version === this.lookupVersion) this.checking = false }
    },
    async submitLogin() {
      if (this.busy) return
      this.error = ''
      if (!this.email || !this.password) { this.error = 'Saisissez votre email et votre mot de passe.'; return }
      this.busy = true
      try {
        const session = await loginAccount({ email: this.email, password: this.password })
        this.password = ''
        this.$emit('login', session)
      } catch (error) { this.error = error.message }
      finally { this.busy = false }
    },
    async submitRegistration() {
      if (this.busy) return
      this.error = ''
      this.errors = profileErrors(this.profile, this.mode === 'join')
      const nameError = organizationError(this.organizationName)
      if (nameError) this.errors.organization_name = nameError
      if (this.mode === 'create') {
        const message = passwordError(this.password)
        if (message) this.errors.password = message
        if (this.password !== this.passwordConfirmation) this.errors.password_confirmation = 'Les mots de passe ne correspondent pas.'
      }
      if (Object.keys(this.errors).length) return
      this.busy = true
      try {
        if (this.mode === 'create') {
          const session = await createOrganization({ name: this.organizationName, profile: profilePayload(this.profile, false), password: this.password })
          this.password = ''
          this.passwordConfirmation = ''
          this.$emit('login', session)
        } else {
          if (!this.organization && !await this.verifyOrganization()) return
          // Re-vérifier côté service/API protège aussi contre une organisation supprimée entre-temps.
          this.receipt = await joinOrganization({ organization_id: this.organization.id, profile: this.profile })
          this.reference = this.receipt.reference
          writeJson(RECEIPT_KEY, { reference: this.reference })
          this.email = this.profile.email
          this.profile = emptyProfile()
          this.changeMode('login')
        }
      } catch (error) { this.error = error.message; this.errors = { ...this.errors, ...errorFields(error) } }
      finally { this.busy = false }
    },
    async refreshStatus() {
      if (this.busy) return
      const reference = this.receipt?.reference || this.reference
      if (!reference) { this.error = 'Saisissez votre référence de suivi.'; return }
      this.busy = true
      this.error = ''
      try { this.receipt = await getRequestStatus(reference); this.reference = reference; writeJson(RECEIPT_KEY, { reference }) }
      catch (error) { this.error = error.message }
      finally { this.busy = false }
    },
    dismissReceipt() { this.receipt = null },
  },
}
</script>

<style scoped>
.login {
  display: grid;
  grid-template-columns: 4fr 5fr;
  min-height: 100vh;
}

.intro {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 60px 76px;
  overflow: hidden;
  background: var(--side-bg);
  color: #ffffff;
}

.deco {
  position: absolute;
  background: rgba(255, 255, 255, 0.45);
}

.deco-a {
  top: 0;
  right: 0;
  width: 192px;
  height: 100px;
}

.deco-b {
  top: 100px;
  right: 192px;
  width: 100px;
  height: 100px;
}

.intro-title {
  font-family: var(--display);
  font-size: clamp(42px, 5vw, 76px);
  font-weight: 400;
  line-height: 1;
  text-transform: uppercase;
}

.intro-title::after {
  content: '';
  display: inline-block;
  width: 0.32em;
  height: 0.1em;
  margin-left: 0.04em;
  background: var(--orange);
}

.intro-eyebrow {
  margin: 44px 0 26px;
  font-size: 14px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.intro-eyebrow::before {
  content: '< ';
  color: var(--mint);
}

.intro-eyebrow::after {
  content: ' />';
  color: var(--mint);
}

.intro-list {
  display: flex;
  flex-direction: column;
  gap: 18px;
  max-width: 510px;
  padding: 0;
  list-style: none;
  font-size: 18px;
  line-height: 1.5;
}

.intro-list li {
  display: flex;
  gap: 16px;
}

.intro-list svg {
  width: 24px;
  height: 24px;
  margin-top: 2px;
}

.pixels {
  position: absolute;
  bottom: 76px;
  left: 76px;
  display: grid;
  grid-template-columns: repeat(7, 16px);
  gap: 9px;
}

.pixels span {
  width: 16px;
  height: 16px;
}

.pixel-light { background: rgba(255, 255, 255, 0.45); }
.pixel-dark { background: #141c66; }
.pixel-orange { background: var(--orange); }

.panel {
  display: flex;
  align-items: center;
  padding: 60px 16px;
  background: var(--bg);
}

.form {
  display: flex;
  flex-direction: column;
  gap: 22px;
  width: min(542px, 100%);
  margin-left: clamp(0px, 10%, 146px);
}

.lede {
  margin-top: -2px;
  font-size: 16px;
  line-height: 1.6;
  color: var(--text-muted);
}

.form .field-label {
  font-size: 16px;
  font-weight: 700;
}

.form .input {
  padding: 13px 16px;
  font-size: 16px;
}

.themes {
  margin: 0;
  padding: 0;
  border: none;
}

.theme-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 14px;
  margin: 10px 0 10px;
}

.theme-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px 12px 14px;
  background: var(--surface);
  border: 2px solid var(--input-border);
  border-radius: var(--radius-sm);
  color: var(--text);
  text-align: left;
}

.theme-card.is-active {
  border-color: var(--brand);
  box-shadow: inset 0 0 0 2px var(--brand);
}

.swatch {
  display: grid;
  grid-template-columns: 1fr 2fr 1fr;
  height: 46px;
  margin-bottom: 6px;
  overflow: hidden;
  border: 1px solid var(--border);
  border-radius: 3px;
}

.theme-name {
  font-size: 16px;
  font-weight: 700;
}

.theme-text {
  font-size: 14px;
  line-height: 1.5;
  color: var(--text-muted);
}

.btn-login {
  padding: 16px 36px;
  font-size: 17px;
}

.demo {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 16px;
  padding-top: 18px;
  border-top: 1px solid var(--border);
  font-size: 14.5px;
  color: var(--text-muted);
}

@media (max-width: 900px) {
  .login {
    grid-template-columns: 1fr;
  }

  .intro {
    padding: 48px 16px 120px;
  }

  .pixels {
    bottom: 32px;
    left: 16px;
  }

  .deco {
    display: none;
  }

  .form {
    margin: 0 auto;
  }
}

@media (max-width: 560px) {
  .theme-grid {
    grid-template-columns: 1fr;
  }
}

.form > form { display: flex; flex-direction: column; gap: 20px; }
.access-nav { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
.access-choice { display: flex; flex-direction: column; align-items: flex-start; gap: 10px; padding: 14px 10px; background: var(--surface); border: 1.5px solid var(--border); border-radius: var(--radius-sm); color: var(--text); text-align: left; font-weight: 600; }
.access-choice svg { width: 22px; height: 22px; color: var(--title); }
.access-choice.active { border-color: var(--brand); background: var(--brand-soft); box-shadow: inset 0 -3px var(--brand); }
.access-choice:hover:not(:disabled) { border-color: var(--brand); }
.organization-check, .actions { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; }
.receipt { display: flex; flex-direction: column; align-items: flex-start; gap: 14px; padding: 22px; }
.receipt .field { width: 100%; }
.receipt .input { font-size: 13px; }
.follow-link { align-self: flex-start; }
@media (max-width: 400px) { .access-nav { grid-template-columns: 1fr; } .access-choice { flex-direction: row; align-items: center; } }

.deco, .pixels { display: none; }
.intro-title { font-family: var(--font); font-size: clamp(32px, 3vw, 48px); font-weight: 700; text-transform: none; letter-spacing: -.04em; }
.intro-title::after, .intro-eyebrow::before, .intro-eyebrow::after { content: none; }
.intro-eyebrow { margin-top: 24px; text-transform: none; }
.intro-list { font-size: 16px; }
.login { grid-template-columns: minmax(280px, 34%) minmax(0, 1fr); }
.panel { justify-content: center; padding: 48px 28px; }
.form { margin: 0; width: min(500px, 100%); }
@media (max-width: 760px) {
 .login { display: block; }
 .intro { display: flex; min-height: auto; padding: 28px 20px; align-items: center; text-align: center; }
 .intro-title { font-size: 28px; }
 .intro-eyebrow { margin: 8px 0 0; }
 .intro-list { display: none; }
 .panel { padding: 28px 20px; }
}

</style>
