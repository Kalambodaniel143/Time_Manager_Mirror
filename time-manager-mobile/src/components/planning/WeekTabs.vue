<template>
  <div class="segmented" role="tablist" aria-label="Semaine affichée">
    <button v-for="(label, i) in labels" :key="i" type="button" role="tab"
      :aria-selected="modelValue === i" :class="{ active: modelValue === i }" @click="$emit('update:modelValue', i)">
      {{ label }}
    </button>
  </div>
</template>

<script>
import { addDays, mondayOf } from '@/ui/dates.js'
import { dayMonth } from '@/ui/format.js'

// Deux onglets : semaine en cours et semaine suivante. v-model = 0 ou 1.
export default {
  name: 'WeekTabs',
  props: { modelValue: { type: Number, default: 0 } },
  emits: ['update:modelValue'],
  computed: {
    labels() {
      return [0, 1].map((i) => {
        const monday = addDays(mondayOf(new Date()), 7 * i)
        return `${dayMonth(monday)} – ${dayMonth(addDays(monday, 6))}`
      })
    },
  },
}
</script>
