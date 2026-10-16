<template>
  <form class="form-grid" @submit.prevent="submit">
    <div class="dates">
      <label>{{ $t('Du') }} <input v-model="from" type="date" required /></label>
      <label>{{ $t('Au') }} <input v-model="to" type="date" :min="from" required /></label>
    </div>
    <p class="small muted">{{ valid ? (days > 1 ? $t('{0} jours', [days]) : $t('{0} jour', [days])) : $t('Entre 1 et 31 jours.') }}</p>
    <button type="submit" :disabled="busy || !valid">{{ label }}</button>
  </form>
</template>

<script>
import { daysBetween } from '@/ui/plans.js'

// Période d'un planning choisie librement (du … au …), 1 à 31 jours comme le serveur.
export default {
  name: 'PeriodForm',
  props: { start: { type: String, required: true }, end: { type: String, required: true }, label: { type: String, required: true }, busy: Boolean },
  emits: ['save'],
  data() { return { from: this.start, to: this.end } },
  computed: {
    days() { return this.from && this.to ? daysBetween(this.from, this.to) : 0 },
    valid() { return this.days >= 1 && this.days <= 31 },
  },
  methods: { submit() { this.$emit('save', { start: this.from, days: this.days }) } },
}
</script>
