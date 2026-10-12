<template>
  <section class="clock-card" aria-label="Pointage">
    <p class="overline">Heure actuelle</p>
    <p class="clock-now">{{ hhmm(now) }}</p>
    <p class="overline">Temps travaillé aujourd’hui</p>
    <p class="clock-worked">{{ clock(worked) }}</p>
    <button v-if="kind" type="button" class="btn-light btn-block" :disabled="disabled" @click="$emit('record', kind)">
      <component :is="kind === 'arrival' ? LogIn : LogOut" :size="18" aria-hidden="true" />
      {{ disabled ? 'Envoi…' : kind === 'arrival' ? 'Pointer mon arrivée' : 'Pointer mon départ' }}
    </button>
  </section>
</template>

<script>
import { markRaw } from 'vue'
import { LogIn, LogOut } from 'lucide-vue-next'
import { hhmm, clock } from '@/ui/format.js'

// Grande carte verte de l'écran Aujourd'hui (heure, temps travaillé, bouton principal).
export default {
  name: 'ClockCard',
  props: {
    now: { type: Date, required: true },
    worked: { type: Number, default: 0 },
    kind: { type: String, default: null }, // 'arrival' | 'departure' | null
    disabled: Boolean,
  },
  emits: ['record'],
  data: () => ({ LogIn: markRaw(LogIn), LogOut: markRaw(LogOut) }),
  methods: { hhmm, clock },
}
</script>
