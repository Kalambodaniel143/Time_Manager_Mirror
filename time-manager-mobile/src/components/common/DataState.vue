<template>
  <p v-if="loading" class="card muted">{{ $t('Chargement…') }}</p>
  <div v-else-if="error" class="card notice-danger">
    <p>{{ error }}</p>
    <button type="button" class="btn-outline" @click="$emit('retry')">{{ $t('Réessayer') }}</button>
  </div>
  <p v-else-if="empty" class="card muted">{{ emptyText }}</p>
  <template v-else>
    <p v-if="stale" class="notice-warn">
      {{ $t('⚠️ {0} · données enregistrées {1}, peut-être plus à jour', [offline ? $t('Hors ligne') : $t('Serveur injoignable'), updatedAt ? ago(updatedAt) : '']) }}
    </p>
    <slot />
  </template>
</template>

<script>
import { t } from '@/i18n/index.js'
import { ago } from '@/ui/format.js'
import { app } from '@/services/appState.js'

// Les états communs à chaque écran : chargement, erreur, vide, données anciennes.
export default {
  name: 'DataState',
  props: {
    loading: Boolean,
    error: { type: String, default: '' },
    empty: Boolean,
    emptyText: { type: String, default: t('Aucune donnée disponible') },
    stale: Boolean,
    updatedAt: { type: String, default: null },
  },
  emits: ['retry'],
  computed: { offline: () => app.network === 'offline' },
  methods: { ago },
}
</script>
