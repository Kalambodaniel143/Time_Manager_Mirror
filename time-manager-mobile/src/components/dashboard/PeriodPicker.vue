<template>
  <fieldset class="card period-picker">
    <legend class="sr-only">Période affichée</legend>
    <div class="chips">
      <button v-for="(p, i) in PRESETS" :key="p.label" type="button" class="btn-outline chip" @click="emit(preset(i))">
        {{ p.label }}
      </button>
    </div>
    <div class="dates">
      <label>Du <input type="date" :value="modelValue.from" :max="modelValue.to" @change="emit({ from: $event.target.value })" /></label>
      <label>Au <input type="date" :value="modelValue.to" :min="modelValue.from" @change="emit({ to: $event.target.value })" /></label>
    </div>
    <div class="segmented" role="group" aria-label="Regrouper les heures">
      <button v-for="u in UNITS" :key="u.value" type="button" :class="{ active: modelValue.unit === u.value }"
        :aria-pressed="modelValue.unit === u.value" @click="emit({ unit: u.value })">{{ u.label }}</button>
    </div>
  </fieldset>
</template>

<script>
import { PRESETS, preset } from '@/ui/period.js'

// Choix de la période (raccourcis ou dates natives) et du regroupement jour/semaine.
// v-model = { from: 'AAAA-MM-JJ', to: 'AAAA-MM-JJ', unit: 'day' | 'week' }
export default {
  name: 'PeriodPicker',
  props: { modelValue: { type: Object, required: true } },
  emits: ['update:modelValue'],
  data: () => ({ PRESETS, UNITS: [{ value: 'day', label: 'Par jour' }, { value: 'week', label: 'Par semaine' }] }),
  methods: {
    preset,
    emit(changes) {
      if (changes.from === '' || changes.to === '') return
      this.$emit('update:modelValue', { ...this.modelValue, ...changes })
    },
  },
}
</script>
