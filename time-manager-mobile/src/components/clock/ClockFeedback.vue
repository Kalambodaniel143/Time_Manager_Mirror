<template>
  <p v-if="refusal" class="notice-danger" role="alert">
    {{ $t('{0} refusé(e) par le serveur : {1}.', [KIND_LABELS[refusal.kind], refusal.reason]) }}
    <RouterLink :to="{ name: 'account' }">{{ $t('Voir le détail') }}</RouterLink>
  </p>
  <p v-else-if="kind" class="notice-ok" role="status">
    ✓ {{ SAVED[kind] }}<template v-if="pending">&nbsp;{{ $t('sur ce téléphone · ⚠️ En attente d’envoi') }}</template>
  </p>
</template>

<script>
import { t } from '@/i18n/index.js'
import { app } from '@/services/appState.js'
import { KIND_LABELS } from '@/ui/format.js'

const SAVED = { arrival: t('Arrivée enregistrée'), departure: t('Départ enregistré'), pause: t('Pause enregistrée'), resume: t('Reprise enregistrée') }

// Retour après un pointage : refus du serveur (avec sa raison) ou confirmation.
export default {
  name: 'ClockFeedback',
  props: { kind: { type: String, default: null } }, // dernier pointage fait sur cet écran
  data: () => ({ KIND_LABELS, SAVED }),
  computed: {
    refusal: () => app.lastRefusal,
    pending: () => app.pending > 0,
  },
}
</script>
