<template>
  <div class="sync-banner" :class="`tone-${state.tone}`">
    <p role="status"><span class="dot" aria-hidden="true" />{{ state.text }}</p>
    <time class="top-clock" :datetime="now.toISOString()" aria-label="Heure actuelle">{{ hhmm(now) }}</time>
  </div>
</template>

<script>
import { app } from '@/services/appState.js'
import { hhmm } from '@/ui/format.js'

const plural = (n, word) => `${n} ${word}${n > 1 ? 's' : ''}`

// Barre du haut, sur tous les écrans : état réseau / synchronisation + heure.
export default {
  name: 'SyncBanner',
  data: () => ({ now: new Date() }),
  computed: {
    state() {
      const waiting = app.pending ? ` · ${plural(app.pending, 'action')} en attente` : ''
      if (app.syncing && app.pending) return { tone: 'info', text: 'Synchronisation en cours…' }
      if (app.network === 'offline') return { tone: 'danger', text: `Hors ligne${waiting}` }
      if (app.network === 'server-down') return { tone: 'warn', text: `Serveur inaccessible${waiting}` }
      if (app.conflicts) return { tone: 'warn', text: `${plural(app.conflicts, 'action')} à vérifier (Mon compte)` }
      if (app.pending) return { tone: 'warn', text: `${plural(app.pending, 'action')} en attente` }
      return { tone: 'ok', text: app.notice || 'En ligne' }
    },
  },
  created() { this.timer = setInterval(() => { this.now = new Date() }, 1000) },
  unmounted() { clearInterval(this.timer) },
  methods: { hhmm },
}
</script>
