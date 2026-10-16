<template>
  <div class="pay-kpis">
    <article v-for="c in CATEGORIES" :key="c" class="card pay-kpi">
      <span class="cat-tag" :class="`cat-${c}`">{{ labels[c] }}</span>
      <strong class="pay-kpi-value">{{ fmt(totals[c]) }}</strong>
      <span class="small muted">{{ hints[c] }}</span>
    </article>
  </div>
</template>

<script>
import { CATEGORIES } from '@/ui/payroll.js'

// Les six catégories d'heures du mois (comme les tuiles de la paie sur le web).
export default {
  name: 'PayKpis',
  props: { totals: { type: Object, required: true }, labels: { type: Object, required: true }, hints: { type: Object, required: true }, fmt: { type: Function, required: true } },
  data: () => ({ CATEGORIES }),
}
</script>
