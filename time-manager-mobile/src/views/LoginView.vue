<template>
  <AuthShell title="Time Manager" :subtitle="`${ORGANIZATION_NAME} · Services municipaux`" :back="false">
    <SegmentedTabs v-model="mode" :options="MODES" label="Connexion ou adhésion" />
    <JoinPanel v-if="mode === 'join'" />
    <template v-else>
      <p v-if="expired" class="notice-warn" role="alert">Votre session a expiré. Reconnectez-vous.</p>
      <form class="form-grid auth-form" @submit.prevent="submit">
        <p class="small muted">Votre e-mail et le mot de passe fourni par le super administrateur vous donnent accès aux services de {{ ORGANIZATION_NAME }}.</p>
        <label for="email">Adresse e-mail</label>
        <input id="email" v-model.trim="email" type="email" autocomplete="username" required />
        <label for="password">Mot de passe</label>
        <PasswordInput id="password" v-model="password" autocomplete="current-password" />
        <p v-if="error" class="field-error" role="alert">{{ error }}</p>
        <button type="submit" :disabled="busy"><LogIn :size="18" aria-hidden="true" /> {{ busy ? 'Connexion…' : 'Se connecter' }}</button>
      </form>
      <ServerStatus />
      <p v-if="demo" class="muted small">Mode démo : messline@example.com, manager@example.com ou admin@example.com — mot de passe demo1234</p>
    </template>
  </AuthShell>
</template>

<script>
import { LogIn } from 'lucide-vue-next'
import AuthShell from '@/components/auth/AuthShell.vue'
import PasswordInput from '@/components/auth/PasswordInput.vue'
import JoinPanel from '@/components/auth/JoinPanel.vue'
import ServerStatus from '@/components/auth/ServerStatus.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import { app } from '@/services/appState.js'
import { login } from '@/services/authService.js'
import { syncNow, refreshCounts } from '@/services/syncService.js'
import { authError } from '@/ui/authErrors.js'
import { DATA_SOURCE, ORGANIZATION_NAME } from '@/config/api.js'

// Comme LoginScreen sur le web : deux choix seulement, se connecter ou rejoindre l'organisation.
export default {
  name: 'LoginView',
  components: { AuthShell, PasswordInput, JoinPanel, ServerStatus, SegmentedTabs, LogIn },
  data() {
    return {
      mode: this.$route.query.mode === 'join' ? 'join' : 'login',
      MODES: [{ value: 'login', label: 'Connexion' }, { value: 'join', label: `Rejoindre ${ORGANIZATION_NAME}` }],
      email: '', password: '', busy: false, error: '', demo: DATA_SOURCE === 'mock', ORGANIZATION_NAME,
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
