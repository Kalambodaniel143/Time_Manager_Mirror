<template>
  <div class="login">
    <div class="auth-theme-controls"><ThemeToggle :model-value="theme" @update:model-value="$emit('update:theme', $event)" /></div>
    <section class="intro">
      <span class="deco deco-a" aria-hidden="true"></span>
      <span class="deco deco-b" aria-hidden="true"></span>
      <div class="intro-body">
        <h1 class="intro-title">Time Manager</h1>
        <p class="intro-eyebrow">Gotham City · Services municipaux</p>
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
          <p v-if="receipt.status === 'pending'">Votre demande attend la décision du super administrateur. Aucun compte n’est encore actif.</p>
          <p v-else-if="receipt.status === 'approved'">Votre demande a été acceptée. Le super administrateur vous fournit votre mot de passe ; utilisez votre email pour vous connecter.</p>
          <p v-else>Votre demande a été refusée. {{ receipt.rejection_reason }}</p>
          <label class="field"><span class="field-label">Référence de suivi à conserver</span><input class="input num" :value="receipt.reference" readonly /></label>
          <div class="actions"><button class="btn btn-outline" type="button" :disabled="busy" @click="refreshStatus">Actualiser le statut</button><button class="btn btn-quiet" type="button" @click="dismissReceipt">Fermer</button></div>
        </div>

        <form v-if="mode === 'login'" novalidate :aria-busy="busy" @submit.prevent="submitLogin">
          <h2 class="page-title">Connexion</h2>
          <p class="lede">Votre email et le mot de passe fourni par le super administrateur vous donnent accès aux services de Gotham City.</p>
          <label class="field"><span class="field-label">Adresse email</span><input v-model.trim="email" class="input" type="email" autocomplete="username" required /></label>
          <label class="field"><span class="field-label">Mot de passe</span><span class="password-control"><input v-model="password" class="input" :type="showLoginPassword ? 'text' : 'password'" autocomplete="current-password" required /><button class="password-toggle" type="button" :aria-label="showLoginPassword ? 'Masquer le mot de passe' : 'Afficher le mot de passe'" :aria-pressed="showLoginPassword" @click="showLoginPassword = !showLoginPassword"><AppIcon :name="showLoginPassword ? 'eye-off' : 'eye'" /></button></span></label>
          <p v-if="error" class="field-error" role="alert">{{ error }}</p>
          <button class="btn btn-primary btn-login" type="submit" :disabled="busy"><AppIcon name="login" />{{ busy ? 'Connexion…' : 'Se connecter' }}</button>
          <p class="field-hint">Demande en attente ? Utilisez « Suivre ma demande » ci-dessous.</p>
        </form>

        <form v-else-if="mode === 'join'" novalidate :aria-busy="busy" @submit.prevent="submitRegistration">
          <div><p class="eyebrow">Services municipaux de Gotham City</p><h2 class="page-title">Rejoindre Gotham City</h2></div>
          <p class="lede">Votre demande est adressée au super administrateur de Gotham City. Après son accord, vous rejoignez les services municipaux en tant qu’employé.</p>
          <ProfileFields v-model="profile" :errors="errors" personal-details />
          <InfoNote title="Votre mot de passe vient du super administrateur" flat>Vous n’avez pas de mot de passe à choisir ici. Après acceptation, le super administrateur définit votre mot de passe et vous transmet vos identifiants.</InfoNote>
          <p v-if="error" class="field-error" role="alert">{{ error }}</p>
          <button class="btn btn-primary btn-login" type="submit" :disabled="busy">{{ busy ? 'Envoi…' : 'Envoyer ma demande' }}</button>
        </form>

        <form v-else novalidate :aria-busy="busy" @submit.prevent="refreshStatus">
          <h2 class="page-title">Suivre ma demande</h2>
          <p class="lede">Saisissez la référence reçue lors de votre demande d’adhésion.</p>
          <label class="field"><span class="field-label">Référence de suivi</span><input v-model.trim="reference" class="input" autocomplete="off" required /></label>
          <p v-if="error" class="field-error" role="alert">{{ error }}</p>
          <button class="btn btn-primary" type="submit" :disabled="busy">{{ busy ? 'Recherche…' : 'Consulter le statut' }}</button>
        </form>

        <button v-if="mode !== 'status'" class="link follow-link" type="button" :disabled="busy" @click="changeMode('status')">Suivre ma demande</button>

        <p v-if="mock" class="field-hint">Simulation locale : les comptes et demandes restent dans ce navigateur. Aucun email n’est envoyé.</p>
      </div>
    </main>
  </div>
</template>

<script>
import ThemeToggle from '../components/ui/ThemeToggle.vue'
import AppIcon from '../components/ui/AppIcon.vue'
import InfoNote from '../components/ui/InfoNote.vue'
import ProfileFields from '../components/auth/ProfileFields.vue'
import { AUTH_USE_MOCK, getRequestStatus, joinOrganization, loginAccount } from '../services/organizationService'
import { emptyProfile, errorFields, profileErrors, profilePayload } from '../utils/registration'
import { readJson, writeJson } from '../utils/session'


const RECEIPT_KEY = 'tm-last-join-receipt'

export default {
  name: 'LoginScreen',
  components: { ThemeToggle, AppIcon, InfoNote, ProfileFields },
  props: { theme: { type: String, required: true }, initialMode: { type: String, default: 'login' } },
  emits: ['login', 'update:theme'],
  data() {
    return {
      showLoginPassword: false, mode: this.initialMode === 'join' ? 'join' : 'login', email: '', password: '',
      profile: emptyProfile(), errors: {}, error: '', busy: false,
      receipt: null, reference: readJson(RECEIPT_KEY, null)?.reference || '', mock: AUTH_USE_MOCK,
      modes: [{ value: 'login', label: 'Connexion', icon: 'login' }, { value: 'join', label: 'Rejoindre Gotham City', icon: 'users' }],
      points: [{ icon: 'users', text: 'Rejoignez les services municipaux de Gotham City.' }, { icon: 'shield', text: 'Le super administrateur examine votre demande et définit vos accès.' }, { icon: 'clock', text: 'Retrouvez vos heures, votre planning et votre équipe.' }],
      pixels: 'llllddllllllolllddllo'.split('').map((code) => ({ l: 'light', d: 'dark', o: 'orange' })[code]),
    }
  },
  computed: {
    statusLabel() { return { pending: 'En attente', approved: 'Acceptée', rejected: 'Refusée' }[this.receipt?.status] || '' },
    statusClass() { return { pending: 'pill-warn', approved: 'pill-ok', rejected: 'pill-danger' }[this.receipt?.status] || '' },
  },
  watch: { initialMode(mode) { this.changeMode(mode === 'join' ? 'join' : 'login') } },
  methods: {
    changeMode(mode) {
      if (!['login', 'join', 'status'].includes(mode)) return
      this.mode = mode
      if (this.$router && ['login', 'join'].includes(mode)) {
        const name = mode === 'join' ? 'register' : 'login'
        if (this.$route.name !== name) this.$router.replace({ name, query: this.$route.query })
      }
      this.error = ''
      this.errors = {}
      this.password = ''
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
      this.errors = profileErrors(this.profile, true)
      if (Object.keys(this.errors).length) return
      this.busy = true
      try {
        this.receipt = await joinOrganization({ profile: profilePayload(this.profile, true) })
        this.reference = this.receipt.reference
        writeJson(RECEIPT_KEY, { reference: this.reference })
        this.email = this.profile.email
        this.profile = emptyProfile()
        this.changeMode('login')
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

}

.form > form { display: flex; flex-direction: column; gap: 20px; }
.access-nav { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
.access-choice { display: flex; flex-direction: column; align-items: flex-start; gap: 10px; padding: 14px 10px; background: var(--surface); border: 1.5px solid var(--border); border-radius: var(--radius-sm); color: var(--text); text-align: left; font-weight: 600; }
.access-choice svg { width: 22px; height: 22px; color: var(--title); }
.access-choice.active { border-color: var(--brand); background: var(--brand-soft); box-shadow: inset 0 -3px var(--brand); }
.access-choice:hover:not(:disabled) { border-color: var(--brand); }
.actions { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; }
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

.login { position: relative; }
.auth-theme-controls { position: absolute; z-index: 1; top: 16px; right: 20px; }
@media (max-width: 760px) { .auth-theme-controls { position: static; display: flex; justify-content: flex-end; padding: 12px 16px; background: var(--bg); } }
</style>
