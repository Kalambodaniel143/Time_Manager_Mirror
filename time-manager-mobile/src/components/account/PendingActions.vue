<template>
  <section v-if="actions.length" class="card">
    <h2>{{ $t('Pointages sur ce téléphone') }}</h2>
    <button v-if="refused > 1" type="button" class="btn-outline btn-block" @click="dismissAll">
      {{ $t('Retirer les {0} pointages refusés', [refused]) }}
    </button>
    <ul class="list">
      <li v-for="a in actions" :key="a.id">
        <div class="row">
          <span>{{ KIND_LABELS[a.kind] }} · {{ longDate(a.time) }} {{ hhmm(a.time) }}</span>
          <span class="badge" :class="a.status === 'conflict' ? 'badge-danger' : 'badge-warn'">
            {{ a.status === 'conflict' ? $t('À vérifier') : $t('En attente') }}
          </span>
        </div>
        <template v-if="a.status === 'conflict'">
          <p class="small muted">{{ $t('Refusé par le serveur : {0}. {1}', [a.error, WHO_FIXES[role]]) }}</p>
          <button type="button" class="btn-quiet" @click="dismiss(a)">{{ $t('J’ai compris, retirer') }}</button>
        </template>
      </li>
    </ul>
  </section>
</template>

<script>
import { app } from '@/services/appState.js'
import { listActions, removeAction } from '@/storage/outboxStore.js'
import { refreshCounts } from '@/services/syncService.js'
import { KIND_LABELS, hhmm, longDate } from '@/ui/format.js'
import { WHO_FIXES } from '@/ui/roleTexts.js'

// Actions en attente d'envoi ou refusées (conflit) : rien ne disparaît sans être vu.
export default {
  name: 'PendingActions',
  data: () => ({ KIND_LABELS, WHO_FIXES }),
  computed: {
    role: () => app.user.role,
    actions() {
      void (app.pending + app.conflicts) // recalcul après chaque synchronisation
      return listActions(app.user.id).filter((a) => a.status !== 'synced')
    },
    refused() { return this.actions.filter((a) => a.status === 'conflict').length },
  },
  methods: {
    hhmm, longDate,
    dismiss(action) {
      removeAction(app.user.id, action.id)
      refreshCounts()
    },
    dismissAll() {
      this.actions.filter((a) => a.status === 'conflict').forEach((a) => removeAction(app.user.id, a.id))
      app.lastRefusal = null
      refreshCounts()
    },
  },
}
</script>
