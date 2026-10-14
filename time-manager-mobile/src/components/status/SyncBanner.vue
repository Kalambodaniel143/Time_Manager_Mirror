<template>
  <div class="sync-banner" :class="`tone-${state.tone}`">
    <p role="status"><span class="dot" aria-hidden="true" />{{ state.text }}</p>
    <time class="top-clock" :datetime="now.toISOString()" :aria-label="$t('Heure actuelle')">{{ hhmm(now) }}</time>
  </div>
</template>

<script>
import { t } from '@/i18n/index.js'
import { app } from '@/services/appState.js'
import { hhmm } from '@/ui/format.js'

const plural = (n, word) => `${n} ${word}${n > 1 ? 's' : ''}`

// Barre du haut, sur tous les écrans : état réseau / synchronisation + heure.
export default {
  name: 'SyncBanner',
  data: () => ({ now: new Date() }),
  computed: {
    state() {
      const waiting = app.pending ? ` · ${t('{0} en attente', [plural(app.pending, 'action')])}` : ''
      if (app.syncing && app.pending) return { tone: 'info', text: t('Synchronisation en cours…') }
      if (app.network === 'offline') return { tone: 'danger', text: t('Hors ligne{0}', [waiting]) }
      if (app.network === 'server-down') return { tone: 'warn', text: t('Serveur inaccessible{0}', [waiting]) }
      if (app.conflicts) return { tone: 'warn', text: t('{0} à vérifier (Mon compte)', [plural(app.conflicts, 'action')]) }
      if (app.pending) return { tone: 'warn', text: t('{0} en attente', [plural(app.pending, 'action')]) }
      return { tone: 'ok', text: app.notice || t('En ligne') }
    },
  },
  created() { this.timer = setInterval(() => { this.now = new Date() }, 1000) },
  unmounted() { clearInterval(this.timer) },
  methods: { hhmm },
}
</script>
