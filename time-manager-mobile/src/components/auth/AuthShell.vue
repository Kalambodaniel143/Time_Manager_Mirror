<template>
  <main class="login-page">
    <LanguageSwitch class="login-lang" />
    <div class="login-logo" aria-hidden="true"><Landmark :size="28" /></div>
    <p v-if="org" class="login-org">{{ org }}</p>
    <h1 class="center">{{ title }}</h1>
    <p v-if="subtitle" class="muted center">{{ subtitle }}</p>
    <slot />
    <RouterLink v-if="back" class="back-to-login" :to="{ name: 'login' }">{{ $t('‹ Retour à la connexion') }}</RouterLink>
  </main>
</template>

<script>
import { Landmark } from 'lucide-vue-next'
import LanguageSwitch from '@/components/common/LanguageSwitch.vue'

// Cadre commun des écrans sans session (connexion, inscription, organisation).
export default {
  name: 'AuthShell',
  components: { Landmark, LanguageSwitch },
  props: {
    title: { type: String, required: true },
    org: { type: String, default: '' },
    subtitle: { type: String, default: '' },
    back: { type: Boolean, default: true },
  },
}
</script>
