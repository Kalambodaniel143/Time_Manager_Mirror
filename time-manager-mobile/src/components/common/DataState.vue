<template>
  <p v-if="loading" class="card muted">Chargement…</p>
  <div v-else-if="error" class="card notice-danger">
    <p>{{ error }}</p>
    <button type="button" class="btn-outline" @click="$emit('retry')">Réessayer</button>
  </div>
  <p v-else-if="empty" class="card muted">{{ emptyText }}</p>
  <template v-else>
    <p v-if="stale" class="notice-warn">
      ⚠️ {{ offline ? 'Hors ligne' : 'Serveur injoignable' }} · données enregistrées {{ updatedAt ? ago(updatedAt) : '' }}, peut-être plus à jour
    </p>
    <slot />
  </template>
</template>

<script>
import { ago } from '@/ui/format.js'
import { app } from '@/services/appState.js'

// Les états communs à chaque écran : chargement, erreur, vide, données anciennes.
export default {
  name: 'DataState',
  props: {
    loading: Boolean,
    error: { type: String, default: '' },
    empty: Boolean,
    emptyText: { type: String, default: 'Aucune donnée disponible' },
    stale: Boolean,
    updatedAt: { type: String, default: null },
  },
  emits: ['retry'],
  computed: { offline: () => app.network === 'offline' },
  methods: { ago },
}
</script>
