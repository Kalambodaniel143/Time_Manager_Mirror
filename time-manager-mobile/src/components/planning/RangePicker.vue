<template>
  <fieldset class="period-picker">
    <legend class="sr-only">{{ $t('Période affichée') }}</legend>
    <div class="segmented" role="group" :aria-label="$t('Période')">
      <button v-for="(p, i) in presets" :key="p.label" type="button" :class="{ active: active === i }"
        :aria-pressed="active === i" @click="$emit('update:modelValue', p.range)">{{ p.label }}</button>
    </div>
    <div class="dates range-dates">
      <label>{{ $t('Du') }} <input type="date" :value="modelValue.from" :max="modelValue.to" @change="set('from', $event.target.value)" /></label>
      <label>{{ $t('Au') }} <input type="date" :value="modelValue.to" :min="modelValue.from" @change="set('to', $event.target.value)" /></label>
    </div>
  </fieldset>
</template>

<script>
import { t } from '@/i18n/index.js'
import { weekRange as week } from '@/ui/weeks.js'

// Période d'affichage d'un planning : raccourcis, ou dates « du … au … » toujours visibles.
// v-model = { from, to } (AAAA-MM-JJ).
export default {
  name: 'RangePicker',
  props: { modelValue: { type: Object, required: true } },
  emits: ['update:modelValue'],
  computed: {
    presets: () => [
      { label: t('Cette semaine'), range: week(0) },
      { label: t('Semaine pro.'), range: week(1) },
      { label: t('4 semaines'), range: week(0, 4) },
    ],
    active() { return this.presets.findIndex((p) => p.range.from === this.modelValue.from && p.range.to === this.modelValue.to) },
  },
  methods: {
    set(key, value) { if (value) this.$emit('update:modelValue', { ...this.modelValue, [key]: value }) },
  },
}

</script>
