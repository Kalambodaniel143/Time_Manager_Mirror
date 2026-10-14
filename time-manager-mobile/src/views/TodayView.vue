<template>
  <PageHeader :eyebrow="longDate(now)" :title="$t('Bonjour {0}', [firstName])">
    <p class="status-line">{{ status }}</p>
  </PageHeader>

  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt" @retry="load">
    <template v-if="state">
      <MissingDeparture v-if="state.missingDeparture" :arrival="state.arrival" @complete="complete" />
      <ClockCard v-else :now="now" :worked="worked" :kind="mainKind" :disabled="busy" @record="record" />

      <p v-if="state.arrival" class="center muted">{{ $t('Arrivée pointée à {0}', [hhmm(state.arrival)]) }}</p>
      <button v-if="breakKind && !state.missingDeparture" type="button" class="btn-outline btn-block btn-card" :disabled="busy" @click="record(breakKind)">
        <component :is="breakKind === 'pause' ? Coffee : Play" :size="18" aria-hidden="true" />
        {{ breakKind === 'pause' ? $t('Prendre une pause') : $t('Reprendre le service') }}
      </button>
      <ClockFeedback :kind="lastKind" />
    </template>
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import { markRaw } from 'vue'
import { Coffee, Play } from 'lucide-vue-next'
import PageHeader from '@/components/common/PageHeader.vue'
import DataState from '@/components/common/DataState.vue'
import ClockCard from '@/components/clock/ClockCard.vue'
import MissingDeparture from '@/components/clock/MissingDeparture.vue'
import ClockFeedback from '@/components/clock/ClockFeedback.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { completeDeparture, getClockState, recordClock } from '@/services/clockService.js'
import { syncNow } from '@/services/syncService.js'
import { statusLabel } from '@/ui/clockState.js'
import { hhmm, longDate } from '@/ui/format.js'


export default {
  name: 'TodayView',
  components: { PageHeader, DataState, ClockCard, MissingDeparture, ClockFeedback },
  mixins: [loadable],
  data: () => ({ Coffee: markRaw(Coffee), Play: markRaw(Play), state: null, loadedAt: new Date(), now: new Date(), lastKind: null, busy: false }),
  computed: {
    firstName: () => app.user.first_name || (app.user.email ?? '').split('@')[0],
    status() { return this.state ? statusLabel(this.state.last) : '' },
    mainKind() { return ['arrival', 'departure'].find((k) => this.state.allowed.includes(k)) },
    breakKind() { return ['pause', 'resume'].find((k) => this.state.allowed.includes(k)) },
    worked() { return this.state.worked + (this.state.running ? this.now - this.loadedAt : 0) },
    pending: () => app.pending,
  },
  // Après une synchronisation, recharger l'état confirmé par le serveur.
  watch: { pending() { this.load({ quiet: true }) } },
  created() {
    this.load()
    this.timer = setInterval(() => { this.now = new Date() }, 1000)
  },
  unmounted() { clearInterval(this.timer) },
  methods: {
    hhmm,
    longDate,
    async load(options) {
      this.state = await this.run(async () => {
        const state = await getClockState()
        return { data: state, stale: state.stale, updatedAt: state.updatedAt }
      }, options)
      this.loadedAt = new Date()
    },
    async complete(time) {
      try {
        await completeDeparture(time, this.state.last)
        this.lastKind = 'departure'
      } catch (error) {
        app.lastRefusal = { kind: 'departure', reason: error.message }
      }
      await this.load({ quiet: true })
    },
    // Un clic à la fois : boutons bloqués le temps de l'envoi (ou 2 s hors ligne),
    // pour ne pas empiler des pointages en double.
    async record(kind, time) {
      if (this.busy) return
      this.busy = true
      app.lastRefusal = null
      try {
        recordClock(kind, time)
        this.lastKind = kind
      } catch {
        this.error = t('Impossible d’enregistrer sur ce téléphone (stockage plein ?).')
      }
      await Promise.all([syncNow(), new Promise((resolve) => setTimeout(resolve, 800))])
      await this.load({ quiet: true })
      this.busy = false
    },
  },
}
</script>
