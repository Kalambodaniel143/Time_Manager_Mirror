<template>
  <RouterView />
</template>

<script>
import { app } from '@/services/appState.js'

// Déconnexion, session expirée ou changement de compte (autre onglet) :
// on quitte aussitôt une page que le nouveau compte n'a pas le droit de voir.
export default {
  name: 'MobileApp',
  computed: {
    user: () => app.user,
  },
  watch: {
    user(user) {
      if (!user) return this.$router.replace({ name: 'login' })
      const { roles, public: isPublic } = this.$route.meta
      if (isPublic || (roles && !roles.includes(user.role))) this.$router.replace({ name: 'home' })
    },
  },
}
</script>
