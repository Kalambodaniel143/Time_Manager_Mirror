<template>
  <form class="card notice-card" @submit.prevent="submit">
    <p>
      <TriangleAlert :size="18" aria-hidden="true" />
      Départ du {{ longDate(arrival) }} non pointé. Il était quelle heure ? Dix secondes suffisent.
    </p>
    <label for="departure-time">Heure de départ</label>
    <input id="departure-time" v-model="time" type="time" required />
    <p v-if="error" class="field-error">{{ error }}</p>
    <button type="submit" class="btn-block">Compléter mon départ</button>
  </form>
</template>

<script>
import { TriangleAlert } from 'lucide-vue-next'
import { longDate } from '@/ui/format.js'
import { addDays, toApiTime } from '@/ui/dates.js'

// Service resté ouvert un jour précédent : l'agent saisit son heure réelle de départ.
export default {
  name: 'MissingDeparture',
  components: { TriangleAlert },
  props: { arrival: { type: String, required: true } },
  emits: ['complete'],
  data: () => ({ time: '', error: '' }),
  methods: {
    longDate,
    submit() {
      const [h, m] = this.time.split(':').map(Number)
      let departure = new Date(this.arrival)
      departure.setHours(h, m, 0, 0)
      if (departure <= new Date(this.arrival)) departure = addDays(departure, 1) // garde de nuit
      if (departure > new Date()) { this.error = 'Le départ ne peut pas être dans le futur.'; return }
      this.$emit('complete', toApiTime(departure))
    },
  },
}
</script>
