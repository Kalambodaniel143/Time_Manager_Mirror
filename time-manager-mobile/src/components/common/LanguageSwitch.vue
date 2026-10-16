<template>
  <div class="lang-switch" role="group" :aria-label="$t('Langue')">
    <button v-for="l in LANGS" :key="l.value" type="button" :class="{ active: $lang.value === l.value }"
      :aria-pressed="$lang.value === l.value" :lang="l.value" @click="choose(l.value)">{{ l.label }}</button>
  </div>
</template>

<script>
import { setLang } from '@/i18n/index.js'

const LANGS = [{ value: 'fr', label: 'Français' }, { value: 'en', label: 'English' }]

// Choix de la langue. L'écran est rechargé pour que tous les textes changent d'un coup.
export default {
  name: 'LanguageSwitch',
  data: () => ({ LANGS }),
  methods: {
    choose(value) {
      if (value === this.$lang.value) return
      setLang(value)
      window.location.reload()
    },
  },
}
</script>
