<template>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!days.length" :empty-text="$t('Aucun pointage pour l’instant.')" @retry="load">
    <section v-for="day in days.slice(0, shown)" :key="day.date" class="card">
      <h2 class="small">{{ longDate(`${day.date}T12:00`) }}</h2>
      <ul class="list flush">
        <li v-for="e in day.events" :key="e.id" class="row">
          <span>{{ KIND_LABELS[e.kind] }}</span>
          <span>
            <span v-if="e.local" class="badge badge-warn">{{ $t('En attente') }}</span>
            <strong>{{ hhmm(e.time) }}</strong>
          </span>
        </li>
      </ul>
    </section>
    <button v-if="days.length > shown" type="button" class="btn-outline" @click="shown += 10">{{ $t('Jours précédents') }}</button>
  </DataState>
</template>

<script>
import DataState from '@/components/common/DataState.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { getPointages } from '@/services/dataService.js'
import { listActions } from '@/storage/outboxStore.js'
import { localDay, toUtcIso } from '@/ui/dates.js'
import { KIND_LABELS, hhmm, longDate } from '@/ui/format.js'

// Historique des pointages, jour par jour (les plus récents en haut).
// Pour soi-même, les pointages pas encore envoyés apparaissent « En attente ».
export default {
  name: 'ClockHistory',
  components: { DataState },
  mixins: [loadable],
  props: { userId: { type: Number, required: true } },
  data: () => ({ events: [], shown: 10, KIND_LABELS }),
  computed: {
    pending: () => app.pending,
    days() {
      const byDay = {}
      for (const e of [...this.events].sort((a, b) => b.time.localeCompare(a.time))) {
        (byDay[localDay(e.time)] ??= []).push(e)
      }
      return Object.entries(byDay).map(([date, events]) => ({ date, events }))
    },
  },
  watch: { pending() { this.load() } },
  created() { this.load() },
  methods: {
    hhmm, longDate,
    async load() {
      const server = (await this.run(() => getPointages(this.userId))) ?? []
      const local = this.userId === app.user.id
        ? listActions(this.userId).filter((a) => a.status === 'pending').map((a) => ({ ...a, local: true }))
        : []
      this.events = [...server.map((c) => ({ ...c, time: toUtcIso(c.time) })), ...local]
    },
  },
}
</script>
