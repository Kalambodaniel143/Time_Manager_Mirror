<template>
  <section class="card rules">
    <h2 class="card-title">{{ $t("Règles de l’organisation") }}</h2>
    <div v-for="rule in rules" :key="rule.key" class="rule">
      <label class="rule-label" :for="`rule-${rule.key}`">{{ $t(rule.label) }}</label>
      <div class="rule-row">
        <input
          :disabled="busy || loading"
          :id="`rule-${rule.key}`"
          class="input rule-input num"
          type="number"
          :min="rule.optional ? 0 : 1"
          :step="rule.decimal ? 0.1 : 1"
          v-model.number="draft[rule.key]"
        />
        <p class="rule-hint">{{ $t(rule.hint) }}</p>
      </div>
    </div>
    <fieldset v-if="!demo" class="page-stack"><legend class="rule-label">{{ $t("Absences rémunérées au taux normal") }}</legend><label><input v-model="draft.paidAbsenceKinds" type="checkbox" value="leave" /> {{ $t("Congés") }}</label><label><input v-model="draft.paidAbsenceKinds" type="checkbox" value="sick" /> {{ $t("Arrêts maladie") }}</label><p class="field-hint">{{ $t("Sans activation, les absences sont suivies mais ne contribuent pas au montant. La récupération prise reste non rémunérée.") }}</p></fieldset>
    <div class="rule">
      <p class="rule-label">{{ $t("Rappel de pointage oublié") }}</p>
      <p class="rule-hint">{{ $t("Les décisions et publications sont notifiées dans l’application.") }}</p>
    </div>
    <p v-if="message" class="field-hint" role="status">{{ $t(message) }}</p>
    <button class="btn btn-primary" type="button" :disabled="loading || busy" @click="save">{{ $t("Enregistrer les règles") }}</button>
  </section>
</template>

<script>
import { org, setRule, isDemoData } from '../../services/orgService'

import { auth } from '../../stores/auth'
import { loadContext, saveRules } from '../../services/workforceService'

const RULES = [
  { key: 'nightMultiplier', label: 'Coefficient des heures de nuit', hint: 'Appliqué aux heures nocturnes hors heures supplémentaires.', decimal: true },
  { key: 'overtimeMultiplier', label: 'Coefficient des heures supplémentaires', hint: 'Les heures supplémentaires sont une catégorie distincte.', decimal: true },
  { key: 'nightStart', label: 'Début des heures de nuit (UTC)', hint: 'Heure entre 0 et 23.', optional: true },
  { key: 'nightEnd', label: 'Fin des heures de nuit (UTC)', hint: 'Heure entre 0 et 23.', optional: true },
  { key: 'maxConsecutiveNights', label: 'Nuits d’affilée au maximum', hint: 'Les dépassements sont signalés dans le suivi des heures. Un planning non conforme ne peut pas être publié.' },
  { key: 'maxNightsPerWeek', label: 'Nuits par semaine au maximum', hint: '0 : pas de limite supplémentaire.', optional: true },
  { key: 'maxNightsPerMonth', label: 'Nuits par mois au maximum', hint: '0 : pas de limite supplémentaire. Le contrôle mensuel complet nécessite les données du serveur.', optional: true },
  { key: 'overtimeThreshold', label: 'Heures sup. au-delà de (par semaine)', hint: 'Heures payées ×2 au-delà de ce seuil.' },
  { key: 'publishDaysAhead', optional: true, label: 'Planning publié au moins (jours avant)', hint: 'Pour que chacun puisse s’organiser.' },
]

export default {
  name: 'OrgRules',

  data() {
    return { rules: RULES, draft: { paidAbsenceKinds: [], nightMultiplier: 1.5, overtimeMultiplier: 2, nightStart: 22, nightEnd: 6, ...org.rules }, message: '', loading: false, busy: false }
  },

  computed: { demo: isDemoData },
  async created() { if (this.demo) return; this.loading = true; try { await loadContext(); this.draft = { ...org.rules } } catch (error) { this.message = error.message } finally { this.loading = false } },
  methods: {
    async save() {
      const invalid = this.rules.some(rule => (rule.decimal ? !Number.isFinite(this.draft[rule.key]) : !Number.isInteger(this.draft[rule.key])) || this.draft[rule.key] < (rule.optional ? 0 : 1))
      if (invalid) { this.message = 'Vérifiez les valeurs : seuls les nombres entiers dans les limites indiquées sont acceptés.'; return }
      if (this.demo) { this.rules.filter(rule => !['nightStart', 'nightEnd', 'nightMultiplier', 'overtimeMultiplier'].includes(rule.key)).forEach(rule => setRule(rule.key, this.draft[rule.key])); this.message = 'Règles enregistrées dans la démonstration.'; return }
      this.busy = true; this.message = ''
      try { const rules = await saveRules(auth.organization?.id, { ...Object.fromEntries(this.rules.map(rule => [rule.key, this.draft[rule.key]])), paidAbsenceKinds: this.draft.paidAbsenceKinds }); Object.assign(org.rules, rules); this.message = 'Règles enregistrées. Les responsables ont reçu une notification.' }
      catch (error) { this.message = error.message }
      finally { this.busy = false }
    },
  },
}
</script>

<style scoped>
.rules {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 24px 24px 26px;
}

.rules .card-title {
  font-size: 19px;
}

.rule-label {
  display: block;
  margin-bottom: 8px;
  font-size: 16px;
  font-weight: 700;
}

.rule-row {
  display: flex;
  align-items: center;
  gap: 14px;
}

.rule-input {
  flex-shrink: 0;
  width: 82px;
  font-size: 16px;
}

.rule-hint {
  font-size: 14px;
  color: var(--text-muted);
}
</style>
