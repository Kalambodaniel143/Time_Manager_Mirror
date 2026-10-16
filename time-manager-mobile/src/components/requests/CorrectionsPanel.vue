<template>
  <details class="card fold" :open="Boolean(period)">
    <summary>{{ $t('Proposer une correction') }}</summary>
    <form class="form-grid" @submit.prevent="send">
      <p class="small muted">{{ $t('Vos heures ne changent qu’après l’accord d’un responsable.') }}</p>
      <label for="cor-period">{{ $t('Période à corriger') }}</label>
      <select id="cor-period" v-model="periodId" required @change="prefill">
        <option v-for="p in periods" :key="p.id" :value="p.id">{{ range(p) }}</option>
      </select>
      <label for="cor-start">{{ $t('Début réel') }}</label>
      <input id="cor-start" v-model="start" type="datetime-local" required />
      <label for="cor-end">{{ $t('Fin réelle') }}</label>
      <input id="cor-end" v-model="end" type="datetime-local" required />
      <label for="cor-reason">{{ $t('Motif') }}</label>
      <textarea id="cor-reason" v-model.trim="reason" rows="2" maxlength="500" required />
      <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
      <button type="submit" :disabled="busy || !periodId">{{ $t('Envoyer la proposition') }}</button>
    </form>
  </details>

  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!items.length" :empty-text="$t('Aucune proposition de correction.')" @retry="load">
    <ul class="list card scroll-box">
      <li v-for="c in items" :key="c.id">
        <p class="row"><strong>{{ range(c.proposal) }}</strong><StatusBadge :status="c.status" /></p>
        <p class="small muted">{{ $t('Avant : {0} · {1}', [range(c.before), c.reason]) }}</p>
        <p v-if="c.review_reason" class="small">{{ $t('Réponse : {0}', [c.review_reason]) }}</p>
      </li>
    </ul>
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import DataState from '@/components/common/DataState.vue'
import StatusBadge from '@/components/common/StatusBadge.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { act, api, read } from '@/services/workforce.js'
import { getMesHeures } from '@/services/dataService.js'
import { parseApiDate } from '@/ui/dates.js'
import { toInput, toUtcText } from '@/ui/weeks.js'
import { dayMonth, hhmm } from '@/ui/format.js'

// Corrections de mes heures (contrat 9.2) : proposition motivée, suivi de la décision.
export default {
  name: 'CorrectionsPanel',
  components: { DataState, StatusBadge },
  mixins: [loadable],
  props: { period: { type: Number, default: null } }, // période choisie depuis Mes heures
  data: () => ({ items: [], periods: [], periodId: null, start: '', end: '', reason: '', busy: false, message: '', ok: false }),
  created() { this.load() },
  methods: {
    range(p) { return p?.start ? `${dayMonth(parseApiDate(p.start))} ${hhmm(parseApiDate(p.start))} – ${hhmm(parseApiDate(p.end))}` : '—' },
    async load() {
      const hours = await getMesHeures().catch(() => null)
      this.periods = (hours?.data ?? []).filter((p) => p.end).slice(-30).reverse()
      if (this.period && !this.periodId && this.periods.some((p) => p.id === this.period)) { this.periodId = this.period; this.prefill() }
      this.items = (await this.run(() => read('corrections', () => api.getCorrections(app.user.id)))) ?? []
    },
    prefill() {
      const p = this.periods.find((x) => x.id === this.periodId)
      if (p) [this.start, this.end] = [toInput(parseApiDate(p.start)), toInput(parseApiDate(p.end))]
    },
    async send() {
      if (this.end <= this.start || new Date(this.end) > new Date()) { [this.ok, this.message] = [false, t('Horaires invalides : fin après le début et pas dans le futur.')]; return }
      this.busy = true
      try {
        await act(() => api.proposeCorrection(this.periodId, { start: toUtcText(this.start), end: toUtcText(this.end), reason: this.reason }))
        Object.assign(this, { ok: true, message: t('Proposition envoyée.'), reason: '' })
        await this.load()
      } catch (e) { [this.ok, this.message] = [false, e.message] } finally { this.busy = false }
    },
  },
}
</script>
