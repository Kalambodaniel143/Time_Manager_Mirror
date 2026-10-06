<template>
  <section class="card">
    <h2>Mon compte</h2>
    <p>Aucun compte connecté.</p>
    <RouterLink class="button-link" :to="{ name: 'login' }">Ouvrir la connexion</RouterLink>
  </section>
</template>

<script>
export default {
  name: 'ProfileView',
  // À intégrer : restoreSession() et logout() sans effacer les actions en attente.
}
</script>
