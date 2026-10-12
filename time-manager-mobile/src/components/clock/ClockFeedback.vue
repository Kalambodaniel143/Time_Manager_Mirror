<template>
  <p v-if="refusal" class="notice-danger" role="alert">
    {{ KIND_LABELS[refusal.kind] }} refusé(e) par le serveur : {{ refusal.reason }}.
    <RouterLink :to="{ name: 'account' }">Voir le détail</RouterLink>
  </p>
  <p v-else-if="kind" class="notice-ok" role="status">
    ✓ {{ SAVED[kind] }}<template v-if="pending"> sur ce téléphone · ⚠️ En attente d’envoi</template>
  </p>
</template>

<script>
import { app } from '@/services/appState.js'
import { KIND_LABELS } from '@/ui/format.js'

const SAVED = { arrival: 'Arrivée enregistrée', departure: 'Départ enregistré', pause: 'Pause enregistrée', resume: 'Reprise enregistrée' }

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
