<template>
  <form class="card form-grid" @submit.prevent="save">
    <h2>{{ $t('Règles de l’organisation') }}</h2>
    <template v-for="f in FIELDS" :key="f.key">
      <label :for="f.key">{{ f.label }} <span class="small muted">{{ f.hint }}</span></label>
      <input :id="f.key" v-model.number="rules[f.key]" type="number" :min="f.min" :max="f.max" :step="f.step ?? 1" inputmode="decimal" required />
    </template>
    <fieldset class="form-grid">
      <legend>{{ $t('Absences rémunérées') }}</legend>
      <label class="choice"><input v-model="rules.paidAbsenceKinds" type="checkbox" value="leave" /> {{ $t('Congé') }}</label>
      <label class="choice"><input v-model="rules.paidAbsenceKinds" type="checkbox" value="sick" /> {{ $t('Maladie') }}</label>
    </fieldset>
    <p class="small muted">{{ $t('Heures de nuit en UTC. 0 désactive un quota de nuits.') }}</p>
    <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
    <button type="submit" :disabled="busy">{{ $t('Enregistrer les règles') }}</button>
  </form>
</template>

<script>
import { t } from '@/i18n/index.js'
import { app } from '@/services/appState.js'
import { act, api } from '@/services/workforce.js'

const FIELDS = [
  { key: 'maxConsecutiveNights', label: t('Nuits consécutives max.'), hint: '1–31', min: 1, max: 31 },
  { key: 'maxNightsPerWeek', label: t('Nuits par semaine max.'), hint: '0–7', min: 0, max: 7 },
  { key: 'maxNightsPerMonth', label: t('Nuits par mois max.'), hint: '0–31', min: 0, max: 31 },
  { key: 'overtimeThreshold', label: t('Seuil d’heures sup. (h/semaine)'), hint: '1–168', min: 1, max: 168 },
  { key: 'publishDaysAhead', label: t('Publier le planning (jours avant)'), hint: '0–365', min: 0, max: 365 },
  { key: 'nightStart', label: t('Début de la nuit (heure)'), hint: '0–23', min: 0, max: 23 },
  { key: 'nightEnd', label: t('Fin de la nuit (heure)'), hint: '0–23', min: 0, max: 23 },
  { key: 'nightMultiplier', label: t('Majoration nuit'), hint: '1–10', min: 1, max: 10, step: 0.1 },
  { key: 'overtimeMultiplier', label: t('Majoration heures sup.'), hint: '1–10', min: 1, max: 10, step: 0.1 },
]

// Règles (PATCH /organizations/:id/rules) : quotas de nuits, seuils, majorations, absences payées.
export default {
  name: 'RulesForm',
  props: { initial: { type: Object, required: true } },
  data() { return { rules: { paidAbsenceKinds: [], ...this.initial }, busy: false, message: '', ok: false, FIELDS } },
  methods: {
    async save() {
      if (this.rules.nightStart === this.rules.nightEnd) { [this.ok, this.message] = [false, t('Le début et la fin de la nuit doivent être différents.')]; return }
      this.busy = true
      try {
        await act(() => api.saveRules(app.organization.id, this.rules))
        Object.assign(this, { ok: true, message: t('Règles enregistrées.') })
      } catch (e) { Object.assign(this, { ok: false, message: e.message }) } finally { this.busy = false }
    },
  },
}
</script>
