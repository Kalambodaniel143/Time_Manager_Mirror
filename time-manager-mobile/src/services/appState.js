import { reactive } from 'vue'

// État partagé par tous les écrans (réactif : l'interface se met à jour seule).
export const app = reactive({
  user: null,             // utilisateur connecté
  organization: null,     // son organisation ({ id, name }) ou null
  sessionExpired: false,
  network: 'online',      // 'online' · 'offline' (pas d'Internet) · 'server-down'
  syncing: false,
  pending: 0,             // actions en attente d'envoi
  conflicts: 0,           // actions refusées, à vérifier
  lastRefusal: null,      // dernier refus du serveur { kind, reason } (affiché sur Aujourd'hui)
  notice: '',             // message court (« Synchronisation terminée »)
})
