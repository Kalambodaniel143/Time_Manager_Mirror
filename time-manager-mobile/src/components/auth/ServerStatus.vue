<template>
  <details class="server-status small" @toggle="$event.target.open && check()">
    <summary>Diagnostic de connexion</summary>
    <dl class="details">
      <div><dt>Mode</dt><dd>{{ demo ? 'Démo (données fictives, aucun serveur)' : 'Serveur réel' }}</dd></div>
      <div><dt>Réseau</dt><dd>{{ native ? 'Natif Android' : 'Navigateur' }}</dd></div>
      <div class="wide"><dt>Adresse</dt><dd>{{ demo ? '—' : native ? address : `${address} (relayé par npm run dev)` }}</dd></div>
      <div class="wide"><dt>Serveur</dt><dd :class="tone">{{ result }}</dd></div>
    </dl>
    <button v-if="!demo" type="button" class="btn-outline btn-block" :disabled="busy" @click="check">Tester à nouveau</button>
  </details>
</template>

<script>
import { API_URL, DATA_SOURCE } from '@/config/api.js'
import { request } from '@/services/http.js'
import { hasNativeHttp } from '@/services/nativeHttp.js'

// Dit où l'application envoie ses requêtes et si le serveur répond.
// GET /auth/session sans session renvoie 401 : c'est la preuve que le serveur est joignable.
export default {
  name: 'ServerStatus',
  data: () => ({ demo: DATA_SOURCE === 'mock', native: hasNativeHttp(), address: API_URL, result: 'Non testé', tone: '', busy: false }),
  methods: {
    async check() {
      if (this.demo || this.busy) return
      this.busy = true
      this.result = 'Test en cours…'
      try {
        await request('/auth/session')
        Object.assign(this, { result: 'Joignable ✓ (session déjà ouverte)', tone: 'ok-text' })
      } catch (error) {
        // 502/503/504 : c'est le relais (Vite, Nginx) qui répond, pas le serveur.
        const reached = error.status > 0 && ![502, 503, 504].includes(error.status)
        this.tone = reached ? 'ok-text' : 'danger-text'
        this.result = reached ? `Joignable ✓ (réponse ${error.status})` : `Injoignable ✗ (${error.kind ?? error.message})`
      } finally {
        this.busy = false
      }
    },
  },
}
</script>
