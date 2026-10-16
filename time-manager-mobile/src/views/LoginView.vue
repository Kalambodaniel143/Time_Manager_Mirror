<template>
  <AuthShell :title="$t('Time Manager')" :org="$t('Mairie de {0}', [ORGANIZATION_NAME])" :subtitle="$t('Pointez vos horaires simplement et en toute sécurité.')" :back="false">
    <SegmentedTabs v-model="mode" :options="MODES" :label="$t('Connexion ou adhésion')" />
    <JoinPanel v-if="mode === 'join'" />
    <template v-else>
      <p v-if="expired" class="notice-warn" role="alert">{{ $t('Votre session a expiré. Reconnectez-vous.') }}</p>
      <form class="form-grid auth-form" @submit.prevent="submit">
        <label for="email">{{ $t('Adresse e-mail') }}</label>
        <div class="field-icon">
          <Mail :size="18" aria-hidden="true" />
          <input id="email" v-model.trim="email" type="email" autocomplete="username" :placeholder="$t('prenom.nom@gotham.gov')" required />
        </div>
        <label for="password">{{ $t('Mot de passe') }}</label>
        <div class="field-icon">
          <Lock :size="18" aria-hidden="true" />
          <PasswordInput id="password" v-model="password" autocomplete="current-password" />
        </div>
        <p v-if="error" class="field-error" role="alert">{{ error }}</p>
        <button type="submit" :disabled="busy"><LogIn :size="18" aria-hidden="true" /> {{ busy ? $t('Connexion…') : $t('Se connecter') }}</button>
      </form>
      <ForgotPassword :email="email" />
      <p class="login-hint"><Info :size="16" aria-hidden="true" />{{ $t('Votre mot de passe vous est remis par le super administrateur quand il accepte votre demande.') }}</p>
    </template>
  </AuthShell>
</template>

<script>
import { t } from '@/i18n/index.js'
import { Info, Lock, LogIn, Mail } from 'lucide-vue-next'
import AuthShell from '@/components/auth/AuthShell.vue'
import PasswordInput from '@/components/auth/PasswordInput.vue'
import JoinPanel from '@/components/auth/JoinPanel.vue'
import ForgotPassword from '@/components/auth/ForgotPassword.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import { app } from '@/services/appState.js'
import { login } from '@/services/authService.js'
import { syncNow, refreshCounts } from '@/services/syncService.js'
import { authError } from '@/ui/authErrors.js'
import { ORGANIZATION_NAME } from '@/config/api.js'

// Comme LoginScreen sur le web : deux choix seulement, se connecter ou rejoindre l'organisation.
export default {
  name: 'LoginView',
  components: { AuthShell, PasswordInput, JoinPanel, ForgotPassword, SegmentedTabs, LogIn, Mail, Lock, Info },
  data() {
    return {
      mode: this.$route.query.mode === 'join' ? 'join' : 'login',
      MODES: [{ value: 'login', label: t('Connexion') }, { value: 'join', label: t('Rejoindre') }],
      email: '', password: '', busy: false, error: '', ORGANIZATION_NAME,
    }
  },
  computed: { expired: () => app.sessionExpired },
  methods: {
    async submit() {
      this.busy = true
      this.error = ''
      try {
        await login(this.email, this.password)
        this.password = '' // jamais conservé, seulement envoyé au serveur
        refreshCounts()
        syncNow() // envoie les actions laissées en attente par CE compte
        this.$router.replace({ name: 'home' })
      } catch (error) {
        this.error = error.kind ? authError(error) : error.message
      } finally {
        this.busy = false
      }
    },
  },
}
</script>
