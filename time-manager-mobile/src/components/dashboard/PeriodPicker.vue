<template>
  <fieldset class="period-picker">
    <legend class="sr-only">{{ $t('Période affichée') }}</legend>
    <div class="segmented" role="group" :aria-label="$t('Période')">
      <button v-for="(p, i) in PRESETS" :key="p.label" type="button" :class="{ active: active === i }"
        :aria-pressed="active === i" @click="emit(preset(i))">{{ p.label }}</button>
    </div>
    <div class="period-tools">
      <div class="unit-switch" role="group" :aria-label="$t('Regrouper les heures')">
        <button v-for="u in UNITS" :key="u.value" type="button" :class="{ active: modelValue.unit === u.value }"
          :aria-pressed="modelValue.unit === u.value" @click="emit({ unit: u.value })">{{ u.label }}</button>
      </div>
      <details class="custom-dates" :open="active === -1">
        <summary>{{ active === -1 ? `${short(modelValue.from)} – ${short(modelValue.to)}` : $t('Autres dates') }}</summary>
        <div class="dates">
          <label>{{ $t('Du') }} <input type="date" :value="modelValue.from" :max="modelValue.to" @change="emit({ from: $event.target.value })" /></label>
          <label>{{ $t('Au') }} <input type="date" :value="modelValue.to" :min="modelValue.from" @change="emit({ to: $event.target.value })" /></label>
        </div>
      </details>
    </div>
  </fieldset>
</template>

<script>
import { t } from '@/i18n/index.js'
import { PRESETS, preset } from '@/ui/period.js'
import { dayMonth } from '@/ui/format.js'

// Choix de la période (raccourcis, ou dates libres repliées) et du regroupement jour / semaine.
// v-model = { from: 'AAAA-MM-JJ', to: 'AAAA-MM-JJ', unit: 'day' | 'week' }
export default {
  name: 'PeriodPicker',
  props: { modelValue: { type: Object, required: true } },
  emits: ['update:modelValue'],
  data: () => ({ PRESETS, UNITS: [{ value: 'day', label: t('Jour') }, { value: 'week', label: t('Semaine') }] }),
  computed: {
    // Raccourci correspondant aux dates choisies (-1 = dates libres).
    active() {
      return PRESETS.findIndex((p, i) => preset(i).from === this.modelValue.from && preset(i).to === this.modelValue.to)
    },
  },
  methods: {
    preset,
    short: (day) => dayMonth(`${day}T12:00`),
    emit(changes) {
      if (changes.from === '' || changes.to === '') return
      this.$emit('update:modelValue', { ...this.modelValue, ...changes })
    },
  },
}
</script>
