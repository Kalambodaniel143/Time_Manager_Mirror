<template>
  <section class="card" aria-labelledby="clock-title">
    <h2 id="clock-title">Mon service</h2>
    <p>Aucun état de pointage disponible pour le moment.</p>
    <ClockActions />
    <p class="muted">Le pointage sera disponible après activation du service.</p>
  </section>
</template>

<script>
import ClockActions from '@/components/clock/ClockActions.vue'

export default {
  name: 'ClockView',
  components: { ClockActions },
  // À intégrer : getClockState(), recordClock(kind), erreurs et attente.
}
</script>
