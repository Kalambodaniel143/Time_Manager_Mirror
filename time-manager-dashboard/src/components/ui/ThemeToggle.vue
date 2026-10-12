<template>
  <div class="theme-toggle" role="group" aria-label="Affichage">
    <button v-for="option in options" :key="option.value" type="button" :class="{ 'is-active': modelValue === option.value }" :aria-label="option.label" :title="option.label" :aria-pressed="modelValue === option.value" @click="$emit('update:modelValue', option.value)">
      <AppIcon :name="option.icon" /><span v-if="option.value === 'contrast'">Contraste</span>
    </button>
  </div>
</template>
<script>
import AppIcon from './AppIcon.vue'
export default {
  name: 'ThemeToggle', components: { AppIcon },
  props: { modelValue: { type: String, required: true } },
  emits: ['update:modelValue'],
  data() { return { options: [{ value: 'light', label: 'Affichage clair', icon: 'sun' }, { value: 'night', label: 'Affichage nuit', icon: 'moon' }, { value: 'contrast', label: 'Contraste élevé', icon: 'contrast' }] } },
}
</script>
<style scoped>
.theme-toggle { display: inline-flex; gap: 3px; padding: 3px; border: 1px solid var(--border); border-radius: 999px; background: var(--surface); }
button { display: inline-flex; align-items: center; justify-content: center; gap: 6px; padding: 8px; border: 0; border-radius: 999px; background: transparent; color: var(--text-muted); font-size: 12px; font-weight: 600; }
button:hover { background: var(--surface-hover); }
button.is-active { background: var(--brand-soft); color: var(--title); }
svg { width: 18px; height: 18px; }
</style>
