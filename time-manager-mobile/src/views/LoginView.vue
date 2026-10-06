<template>
  <main class="login-page">
    <p class="brand">Time Manager</p>
    <h1>Connexion</h1>
    <form class="card" @submit.prevent="submit">
      <label for="identifier">Identifiant</label>
      <input id="identifier" v-model.trim="identifier" autocomplete="username" required />
      <label for="password">Mot de passe</label>
      <input id="password" v-model="password" type="password" autocomplete="current-password" required />
      <button type="submit" disabled>Se connecter</button>
      <p class="muted">La connexion n’est pas encore disponible dans cet aperçu.</p>
    </form>
    <RouterLink :to="{ name: 'clock' }">Revenir à l’aperçu des écrans</RouterLink>
  </main>
</template>

<script>
export default {
  name: 'LoginView',
  data() {
    return { identifier: '', password: '' }
  },
  methods: {
    submit() {
      // Brancher authService.login() après intégration du contrat serveur par Jonas.
      // Ne jamais conserver le mot de passe dans un stockage persistant.
      this.password = ''
    },
  },
}
</script>
