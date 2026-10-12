<template>
  <main class="login-page">
    <div class="login-logo" aria-hidden="true"><Landmark :size="26" /></div>
    <h1 class="center">{{ title }}</h1>
    <p v-if="subtitle" class="muted center">{{ subtitle }}</p>
    <slot />
    <RouterLink v-if="back" class="back-to-login" :to="{ name: 'login' }">‹ Retour à la connexion</RouterLink>
  </main>
</template>

<script>
import { Landmark } from 'lucide-vue-next'

// Cadre commun des écrans sans session (connexion, inscription, organisation).
export default {
  name: 'AuthShell',
  components: { Landmark },
  props: {
    title: { type: String, required: true },
    subtitle: { type: String, default: '' },
    back: { type: Boolean, default: true },
  },
}
</script>
