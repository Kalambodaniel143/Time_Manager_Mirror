<template>
  <div class="account-identity">
    <span class="avatar" aria-hidden="true">{{ initials }}</span>
    <div class="identity"><strong>{{ session.user.first_name }} {{ session.user.last_name }}</strong><span>{{ roleLabel }}</span><span class="email">{{ session.user.email }}</span><button type="button" @click="$emit('logout')">Se déconnecter</button></div>
  </div>
</template>
<script>
export default {
  name: 'AccountIdentity',
  props: { session: { type: Object, required: true } },
  emits: ['logout'],
  computed: {
    initials() { return `${this.session.user.first_name[0] || ''}${this.session.user.last_name[0] || ''}`.toUpperCase() },
    roleLabel() { return { admin: 'Administrateur', employee: 'Employé', manager: 'Manager' }[this.session.role] },
  },
}
</script>
<style scoped>
.account-identity { display: flex; align-items: flex-start; gap: 12px; margin-top: 18px; padding-top: 18px; border-top: 1px solid var(--side-muted); }
.avatar { display: grid; place-items: center; flex-shrink: 0; width: 42px; height: 42px; border-radius: 50%; background: var(--side-active-bg); color: var(--side-active-ink); font-weight: 700; }
.identity { display: flex; flex-direction: column; gap: 3px; min-width: 0; color: var(--side-ink); }
.identity span { color: var(--side-muted); font-size: 13px; }
.email { overflow-wrap: anywhere; }
.identity button { align-self: flex-start; padding: 4px 0; border: 0; background: none; color: var(--side-ink); text-decoration: underline; text-underline-offset: 3px; }
</style>
