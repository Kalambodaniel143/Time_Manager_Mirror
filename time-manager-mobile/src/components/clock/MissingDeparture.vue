<template>
  <form class="card notice-card" @submit.prevent="submit">
    <p>
      <TriangleAlert :size="18" aria-hidden="true" />
      {{ $t('Départ non pointé pour le service commencé le {0} à {1}.', [longDate(arrival), hhmm(arrival)]) }}
    </p>
    <p v-if="shift" class="small">
      {{ $t('Horaire prévu au planning : {0} → {1}', [hhmm(shift.start), when(shift.end)]) }}
      <button type="button" class="btn-quiet small" @click="usePlanned">{{ $t('Utiliser la fin prévue') }}</button>
    </p>
    <label for="departure-time">{{ $t('Heure de départ') }}</label>
    <input id="departure-time" v-model="time" type="time" required />
    <SegmentedTabs v-model="nextDay" :options="days" :label="$t('Jour du départ')" />
    <p class="small" :class="suspicious ? 'danger-text' : 'muted'">{{ $t('Départ le {0} · service de {1}', [when(departure), hours(duration)]) }}</p>
    <p v-if="error" class="field-error" role="alert">{{ error }}</p>
    <button type="submit" class="btn-block">{{ $t('Compléter mon départ') }}</button>
  </form>
</template>

<script>
import { t } from '@/i18n/index.js'
import { TriangleAlert } from 'lucide-vue-next'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import { app } from '@/services/appState.js'
import { api, read } from '@/services/workforce.js'
import { addDays, localDay, sameDay, toApiTime } from '@/ui/dates.js'
import { dayMonth, hhmm, hours, longDate } from '@/ui/format.js'
import { shiftsOf } from '@/ui/plans.js'

const HOUR = 3_600_000
const LONG = 14 * HOUR // au-delà, sans horaire prévu aussi long : on demande confirmation

// Service resté ouvert : l'agent indique l'heure de son départ ET le jour (même jour ou lendemain).
// 1. Si le planning publié a un créneau pour ce service, sa fin est proposée (nuit 22 h → 6 h comprise).
// 2. Sinon : arrivée le soir (après 18 h) = service de nuit probable, donc le lendemain par défaut.
// 3. Un service bien plus long que prévu (ou > 14 h sans créneau prévu) demande une confirmation.
export default {
  name: 'MissingDeparture',
  components: { TriangleAlert, SegmentedTabs },
  props: { arrival: { type: String, required: true } },
  emits: ['complete'],
  data() {
    const start = new Date(this.arrival)
    const evening = start.getHours() >= 18
    const guess = new Date(start.getTime() + 8 * HOUR)
    return { shift: null, time: hhmm(guess), nextDay: evening ? 1 : 0, error: '' }
  },
  computed: {
    days() {
      const start = new Date(this.arrival)
      return [{ value: 0, label: t('Le {0}', [dayMonth(start)]) }, { value: 1, label: t('Le lendemain ({0})', [dayMonth(addDays(start, 1))]) }]
    },
    departure() {
      const [h, m] = (this.time || '0:0').split(':').map(Number)
      const d = addDays(new Date(this.arrival), this.nextDay)
      d.setHours(h, m, 0, 0)
      return d
    },
    duration() { return this.departure - new Date(this.arrival) },
    // Écart de plus de 3 h avec l'horaire prévu, ou plus de 14 h sans horaire prévu.
    suspicious() {
      if (this.shift) return Math.abs(this.departure - new Date(this.shift.end)) > 3 * HOUR
      return this.duration > LONG
    },
  },
  async created() {
    // Créneau publié qui correspond à cette arrivée (début à ± 4 h).
    const start = new Date(this.arrival)
    const [from, to] = [localDay(addDays(start, -1)), localDay(addDays(start, 1))]
    try {
      const plans = (await read(`plans:${from}:${to}`, () => api.getPlans(from, to))).data
      this.shift = shiftsOf(plans).find((s) => s.user_id === app.user.id && Math.abs(new Date(s.start) - start) <= 4 * HOUR) ?? null
      if (this.shift) this.usePlanned()
    } catch { /* pas de planning sur le serveur : valeurs par défaut */ }
  },
  methods: {
    hhmm, hours, longDate,
    when(date) { return sameDay(date, this.arrival) ? hhmm(date) : `${dayMonth(date)} ${hhmm(date)}` },
    usePlanned() {
      const end = new Date(this.shift.end)
      this.time = hhmm(end)
      this.nextDay = sameDay(end, this.arrival) ? 0 : 1
    },
    submit() {
      this.error = ''
      if (this.duration <= 0) { this.error = t('Le départ doit être après l’arrivée : choisissez « le lendemain » pour un service de nuit.'); return }
      if (this.departure > new Date()) { this.error = t('Le départ ne peut pas être dans le futur.'); return }
      if (this.suspicious && !window.confirm(t('Service de {0}, différent de ce qui était prévu. Confirmer ce départ ?', [hours(this.duration)]))) return
      this.$emit('complete', toApiTime(this.departure))
    },
  },
}
</script>
