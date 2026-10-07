<template>
  <section class="card rules">
    <h2 class="card-title">Règles de l’organisation</h2>
    <div v-for="rule in rules" :key="rule.key" class="rule">
      <label class="rule-label" :for="`rule-${rule.key}`">{{ rule.label }}</label>
      <div class="rule-row">
        <input
          :id="`rule-${rule.key}`"
          class="input rule-input num"
          type="number"
          :min="rule.optional ? 0 : 1"
          v-model.number="draft[rule.key]"
        />
        <p class="rule-hint">{{ rule.hint }}</p>
      </div>
    </div>
    <div class="rule">
      <p class="rule-label">Rappel de pointage oublié</p>
      <p class="rule-hint">Un rappel sobre après le départ attendu. Les messages automatiques restent à raccorder.</p>
    </div>
    <p v-if="message" class="field-hint" role="status">{{ message }}</p>
    <button class="btn btn-primary" type="button" @click="save">Enregistrer les règles</button>
  </section>
</template>

<script>
import { org, setRule } from '../../services/orgService'

const RULES = [
  { key: 'maxConsecutiveNights', label: 'Nuits d’affilée au maximum', hint: 'Au-delà, l’agent et son manager reçoivent une alerte.' },
  { key: 'maxNightsPerWeek', label: 'Nuits par semaine au maximum', hint: '0 : pas de limite supplémentaire.', optional: true },
  { key: 'maxNightsPerMonth', label: 'Nuits par mois au maximum', hint: '0 : pas de limite supplémentaire. Le contrôle mensuel complet nécessite les données du serveur.', optional: true },
  { key: 'overtimeThreshold', label: 'Heures sup. au-delà de (par semaine)', hint: 'Heures payées ×2 au-delà de ce seuil.' },
  { key: 'publishDaysAhead', label: 'Planning publié au moins (jours avant)', hint: 'Pour que chacun puisse s’organiser.' },
]

export default {
  name: 'OrgRules',

  data() {
    return { rules: RULES, draft: { ...org.rules }, message: '' }
  },

  methods: {
    save() {
      const invalid = this.rules.some(rule => !Number.isInteger(this.draft[rule.key]) || this.draft[rule.key] < (rule.optional ? 0 : 1))
      if (invalid) { this.message = 'Vérifiez les valeurs : seuls les nombres entiers dans les limites indiquées sont acceptés.'; return }
      this.rules.forEach(rule => setRule(rule.key, this.draft[rule.key]))
      this.message = 'Règles enregistrées localement. Aucune notification n’a été envoyée.'
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
