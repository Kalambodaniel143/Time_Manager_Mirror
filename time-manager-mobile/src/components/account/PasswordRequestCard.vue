<template>
  <section class="card form-grid">
    <h2>{{ $t('Mot de passe') }}</h2>
    <p class="small muted">{{ $t('Un code est envoyé à votre adresse e-mail pour confirmer le changement.') }}</p>
    <ForgotPassword :email="email" :title="$t('Changer mon mot de passe')" />
  </section>
</template>

<script>
import { app } from '@/services/appState.js'
import ForgotPassword from '@/components/auth/ForgotPassword.vue'

// Mon compte (agents et responsables) : même parcours que « Mot de passe oublié ? »,
// code reçu par e-mail puis nouveau mot de passe. Les autres sessions sont alors fermées.
export default {
  name: 'PasswordRequestCard',
  components: { ForgotPassword },
  computed: { email: () => app.user?.email ?? '' },
}
</script>
