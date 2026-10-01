<template>
  <div class="segmented" role="radiogroup" :aria-label="label">
    <button
      v-for="option in options"
      :key="option.value"
      class="segment"
      :class="{ 'is-active': option.value === modelValue }"
      type="button"
      role="radio"
      :aria-checked="option.value === modelValue"
      @click="$emit('update:modelValue', option.value)"
    >
      {{ option.label }}
    </button>
  </div>
</template>

<script>
export default {
  name: 'SegmentedControl',

  props: {
    modelValue: { type: String, required: true },
    options: { type: Array, required: true },
    label: { type: String, required: true },
  },

  emits: ['update:modelValue'],
}
</script>

<style scoped>
.segmented {
  display: grid;
  grid-auto-columns: 1fr;
  grid-auto-flow: column;
  gap: 4px;
  padding: 4px;
  background: var(--side-well);
  border-radius: var(--radius-sm);
}

.segment {
  padding: 9px 4px;
  background: transparent;
  border: none;
  border-radius: 4px;
  color: var(--side-ink);
  font-size: 14px;
  font-weight: 600;
}

.segment:hover:not(.is-active) {
  background: rgba(255, 255, 255, 0.1);
}

.segment.is-active {
  background: var(--side-active-bg);
  color: var(--side-active-ink);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.25);
}
</style>
