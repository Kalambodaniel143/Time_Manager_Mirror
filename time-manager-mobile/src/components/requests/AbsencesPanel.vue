<template>
  <details class="card fold">
    <summary>{{ $t('Demander une absence') }}</summary>
    <form class="form-grid" @submit.prevent="send">
      <label for="abs-kind">{{ $t('Type') }}</label>
      <select id="abs-kind" v-model="form.kind">
        <option v-for="(label, value) in ABSENCE_KINDS" :key="value" :value="value">{{ label }}</option>
      </select>
      <label for="abs-start">{{ $t('Début') }}</label>
      <input id="abs-start" v-model="form.start" type="datetime-local" required />
      <label for="abs-end">{{ $t('Fin') }}</label>
      <input id="abs-end" v-model="form.end" type="datetime-local" required />
      <label for="abs-reason">{{ $t('Motif') }}</label>
      <textarea id="abs-reason" v-model.trim="form.reason" rows="2" maxlength="500" />
      <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
      <button type="submit" :disabled="busy">{{ $t('Envoyer la demande') }}</button>
    </form>
  </details>

  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!mine.length" :empty-text="$t('Aucune demande d’absence.')" @retry="load">
    <ul class="list card scroll-box">
      <li v-for="a in mine" :key="a.id" class="form-grid">
        <p class="row"><strong>{{ ABSENCE_KINDS[a.kind] ?? a.kind }}</strong><StatusBadge :status="a.status" /></p>
        <p class="small muted">{{ when(a.start) }} → {{ when(a.end) }}<template v-if="a.reason"> · {{ a.reason }}</template></p>
        <button v-if="a.status === 'pending'" type="button" class="btn-quiet" :disabled="busy" @click="cancel(a)">{{ $t('Retirer la demande') }}</button>
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
import { ABSENCE_KINDS } from '@/ui/statusLabels.js'
import { fromInput } from '@/ui/weeks.js'
import { dayMonth, hhmm } from '@/ui/format.js'

const EMPTY = () => ({ kind: 'leave', start: '', end: '', reason: '' })

// Mes absences : congé, maladie, récupération (POST /absence-requests), retrait si en attente.
export default {
  name: 'AbsencesPanel',
  components: { DataState, StatusBadge },
  mixins: [loadable],
  data: () => ({ items: [], form: EMPTY(), busy: false, message: '', ok: false, ABSENCE_KINDS }),
  computed: { mine() { return this.items.filter((a) => (a.user_id ?? app.user.id) === app.user.id) } },
  created() { this.load() },
  methods: {
    when: (date) => `${dayMonth(date)} ${hhmm(date)}`,
    async load() { this.items = (await this.run(() => read('absences', () => api.getAbsences()))) ?? [] },
    async attempt(task, done) {
      this.busy = true
      try { await task(); [this.ok, this.message] = [true, done]; await this.load() } catch (e) { [this.ok, this.message] = [false, e.message] }
      finally { this.busy = false }
    },
    send() {
      if (this.form.end <= this.form.start) { [this.ok, this.message] = [false, t('La fin doit être après le début.')]; return }
      const { kind, reason } = this.form
      this.attempt(() => act(() => api.requestAbsence({ kind, reason, start: fromInput(this.form.start), end: fromInput(this.form.end) })), t('Demande envoyée à votre responsable.'))
        .then(() => { if (this.ok) this.form = EMPTY() })
    },
    cancel(absence) {
      const reason = window.prompt('Pourquoi retirez-vous cette demande ?')
      if (reason?.trim()) this.attempt(() => act(() => api.cancelAbsence(absence.id, reason.trim())), t('Demande retirée.'))
    },
  },
}
</script>
