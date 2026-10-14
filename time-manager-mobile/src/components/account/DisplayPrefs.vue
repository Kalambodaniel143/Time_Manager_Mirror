<template>
  <fieldset class="card">
    <legend><h2>{{ $t('Préférences d’affichage') }}</h2></legend>
    <label v-for="t in THEMES" :key="t.value" class="choice" :class="{ selected: display.theme === t.value }">
      <input v-model="display.theme" type="radio" name="theme" :value="t.value" @change="save" />
      {{ t.label }}
    </label>
    <label class="choice">
      <input v-model="display.largeText" type="checkbox" @change="save" />
      {{ $t('Utiliser des textes renforcés') }}
    </label>
    <p class="lang-row"><span>{{ $t('Langue') }}</span><LanguageSwitch /></p>
  </fieldset>
</template>

<script>
import LanguageSwitch from '@/components/common/LanguageSwitch.vue'
import { THEMES, applyDisplay, getDisplay } from '@/ui/theme.js'

// Thème Clair / Nuit / Contraste élevé, appliqué tout de suite et mémorisé.
export default {
  name: 'DisplayPrefs',
  components: { LanguageSwitch },
  data: () => ({ THEMES, display: getDisplay() }),
  methods: { save() { applyDisplay(this.display) } },
}
</script>
