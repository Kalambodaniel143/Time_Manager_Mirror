<template>
  <section class="card form-grid">
    <h2>Corriger les heures</h2>
    <p class="small muted">Périodes des 14 derniers jours. Les modifications sont enregistrées sur le serveur.</p>
    <p v-if="message" class="small" :class="ok ? 'notice-ok' : 'notice-danger'" role="status">{{ message }}</p>
    <ul class="list flush">
      <li v-for="p in recent" :key="p.id" class="period-row">
        <template v-if="editing === p.id">
          <PeriodFields v-model="form" />
          <div class="request-actions">
            <button type="button" class="btn-outline" @click="editing = null">Annuler</button>
            <button type="button" :disabled="busy" @click="save(p)">Enregistrer</button>
          </div>
        </template>
        <div v-else class="row">
          <span>{{ shortDay(p.start) }} · {{ hhmm(p.start) }} → {{ hhmm(p.end) }}<br><span class="small muted">{{ hours(p.end - p.start) }}</span></span>
          <span>
            <button type="button" class="btn-quiet" @click="edit(p)">Modifier</button>
            <button type="button" class="btn-quiet danger-text" :disabled="busy" @click="remove(p)">Supprimer</button>
          </span>
        </div>
      </li>
    </ul>
    <p v-if="!recent.length" class="muted small">Aucune période sur 14 jours.</p>
    <h3 class="small">Ajouter une période</h3>
    <PeriodFields v-model="draft" />
    <button type="button" :disabled="busy || !draft.start || !draft.end" @click="add">Ajouter</button>
  </section>
</template>

<script>
import PeriodFields from './PeriodFields.vue'
import { getMesHeures } from '@/services/dataService.js'
import { addPeriod, editPeriod, removePeriod } from '@/services/manageService.js'
import { toPeriods } from '@/ui/aggregate.js'
import { addDays } from '@/ui/dates.js'
import { hhmm, hours, shortDay } from '@/ui/format.js'
import { confirmAction } from '@/native/device.js'

const toLocalInput = (date) => new Date(date - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
const toApi = ({ start, end }) => ({ start: new Date(start).toISOString(), end: new Date(end).toISOString() })

// Responsable (son équipe, pas soi) ou administration : créer, corriger, supprimer une période.
export default {
  name: 'PeriodEditor',
  components: { PeriodFields },
  props: { userId: { type: Number, required: true } },
  emits: ['changed'],
  data: () => ({ periods: [], editing: null, form: {}, draft: { start: '', end: '' }, busy: false, message: '', ok: false }),
  computed: {
    recent() {
      const from = addDays(new Date(), -14)
      return this.periods.filter((p) => p.start >= from).sort((a, b) => b.start - a.start)
    },
  },
  created() { this.load() },
  methods: {
    hhmm, hours, shortDay,
    async load() { this.periods = toPeriods((await getMesHeures(this.userId).catch(() => null))?.data) },
    edit(p) { this.editing = p.id; this.form = { start: toLocalInput(p.start), end: toLocalInput(p.end) } },
    async act(task, success) {
      this.busy = true
      try { await task(); this.ok = true; this.message = success; this.editing = null; await this.load(); this.$emit('changed') }
      catch (error) { this.ok = false; this.message = error.message }
      finally { this.busy = false }
    },
    save(p) { return this.act(() => editPeriod(p.id, toApi(this.form)), 'Période corrigée.') },
    async add() {
      await this.act(() => addPeriod(this.userId, toApi(this.draft)), 'Période ajoutée.')
      if (this.ok) this.draft = { start: '', end: '' }
    },
    async remove(p) {
      if (await confirmAction(`Supprimer la période du ${shortDay(p.start)} (${hhmm(p.start)} → ${hhmm(p.end)}) ?`)) {
        this.act(() => removePeriod(p.id), 'Période supprimée.')
      }
    },
  },
}
</script>
