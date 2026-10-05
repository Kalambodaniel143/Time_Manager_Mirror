<template>
  <div class="user-card">
    <RouterLink class="avatar" :to="{ name: 'profile' }" :aria-label="`Profil de ${user.username}`">{{ badge }}</RouterLink>
    <div class="user-text">
      <RouterLink class="user-name" :to="{ name: 'profile' }">{{ user.username }}</RouterLink>
      <p class="user-job">{{ roleLabel }}</p>
      <button class="user-logout" type="button" @click="$emit('logout')">Se déconnecter</button>
    </div>
  </div>
</template>

<script>
import { RouterLink } from 'vue-router'
import { ROLE_LABELS } from '../stores/auth'

// The logged-in user, shown on every page. Logging in, registering and editing
// the profile are the Authentication, Registration and Profile components.
export default {
  name: 'User',

  components: { RouterLink },

  props: {
    user: { type: Object, required: true },
  },

  emits: ['logout'],

  computed: {
    badge() {
      const parts = this.user.username.split(/[\s._-]+/).filter(Boolean)
      return parts.map((part) => part[0]).join('').slice(0, 2).toUpperCase()
    },

    roleLabel() {
      return ROLE_LABELS[this.user.role] || this.user.role
    },
  },
}
</script>

<style scoped>
.user-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding-top: 18px;
  border-top: 1px solid rgba(255, 255, 255, 0.25);
}

.avatar {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 46px;
  height: 46px;
  background: #ffffff;
  border-radius: 50%;
  color: #0037ff;
  font-size: 15px;
  font-weight: 700;
  text-decoration: none;
}

.user-text {
  min-width: 0;
}

.user-name {
  color: var(--side-ink);
  font-size: 15.5px;
  font-weight: 700;
  text-decoration: none;
  overflow-wrap: anywhere;
}

.user-job {
  font-size: 14px;
  color: var(--side-muted);
}

.user-logout {
  padding: 0;
  background: none;
  border: none;
  color: var(--side-ink);
  font-size: 14px;
  text-decoration: underline;
  text-underline-offset: 3px;
}
</style>
