<template>
  <div class="segmented" role="tablist" :aria-label="label">
    <button v-for="o in options" :key="o.value" type="button" role="tab" :aria-selected="modelValue === o.value"
      :class="{ active: modelValue === o.value }" @click="$emit('update:modelValue', o.value)">{{ o.label }}</button>
  </div>
</template>

<script>
import { t } from '@/i18n/index.js'
// Onglets à deux ou trois choix. v-model = valeur choisie ; options = [{ value, label }].
export default {
  name: 'SegmentedTabs',
  props: {
    modelValue: { type: [String, Number], required: true },
    options: { type: Array, required: true },
    label: { type: String, default: t('Affichage') },
  },
  emits: ['update:modelValue'],
}
</script>
