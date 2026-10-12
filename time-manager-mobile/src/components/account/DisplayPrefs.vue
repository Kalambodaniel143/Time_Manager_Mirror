<template>
  <fieldset class="card">
    <legend><h2>Préférences d’affichage</h2></legend>
    <label v-for="t in THEMES" :key="t.value" class="choice" :class="{ selected: display.theme === t.value }">
      <input v-model="display.theme" type="radio" name="theme" :value="t.value" @change="save" />
      {{ t.label }}
    </label>
    <label class="choice">
      <input v-model="display.largeText" type="checkbox" @change="save" />
      Utiliser des textes renforcés
    </label>
  </fieldset>
</template>

<script>
import { THEMES, applyDisplay, getDisplay } from '@/ui/theme.js'

// Thème Clair / Nuit / Contraste élevé, appliqué tout de suite et mémorisé.
export default {
  name: 'DisplayPrefs',
  data: () => ({ THEMES, display: getDisplay() }),
  methods: { save() { applyDisplay(this.display) } },
}
</script>
