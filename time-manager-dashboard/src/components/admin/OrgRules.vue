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
          min="1"
          :value="values[rule.key]"
          @change="update(rule.key, $event)"
        />
        <p class="rule-hint">{{ rule.hint }}</p>
      </div>
    </div>
    <div class="rule">
      <p class="rule-label">Rappel de pointage oublié</p>
      <p class="rule-hint">Un seul message, le lendemain à 9 h. Jamais de relance.</p>
    </div>
  </section>
</template>

<script>
import { org, setRule } from '../../services/orgService'

const RULES = [
  { key: 'maxConsecutiveNights', label: 'Nuits d’affilée au maximum', hint: 'Au-delà, l’agent et son manager reçoivent une alerte.' },
  { key: 'overtimeThreshold', label: 'Heures sup. au-delà de (par semaine)', hint: 'Heures payées ×2 au-delà de ce seuil.' },
  { key: 'publishDaysAhead', label: 'Planning publié au moins (jours avant)', hint: 'Pour que chacun puisse s’organiser.' },
]

export default {
  name: 'OrgRules',

  data() {
    return { rules: RULES }
  },

  computed: {
    values() {
      return org.rules
    },
  },

  methods: {
    update(key, event) {
      setRule(key, event.target.value)
      event.target.value = org.rules[key]
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
