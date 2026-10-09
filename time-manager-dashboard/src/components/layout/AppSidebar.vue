<template>
  <div class="sidebar-shell">
    <header class="mobile-header"><RouterLink class="brand" :to="homeRoute">Time Manager</RouterLink><ThemeToggle class="mobile-theme-controls" :model-value="theme" @update:model-value="$emit('update:theme', $event)" /><button class="btn btn-outline btn-sm" type="button" :aria-expanded="open" aria-controls="sidebar" @click="open = !open">{{ open ? 'Fermer' : 'Menu' }}</button></header>
    <button v-if="open" class="menu-backdrop" type="button" aria-label="Fermer le menu" @click="open = false"></button>
    <aside id="sidebar" class="sidebar" :class="{ 'is-open': open }" @keydown.esc="open = false">
      <RouterLink class="brand" :to="homeRoute" @click="open = false">Time Manager</RouterLink>
      <p class="space">{{ space }}</p>
      <nav class="nav" aria-label="Navigation principale">
        <RouterLink v-for="item in links" :key="item.label" class="nav-link" :to="item.to" active-class="is-active" @click="open = false"><AppIcon :name="item.icon" />{{ item.label }}</RouterLink>
      </nav>
      <div class="settings"><ThemeToggle :model-value="theme" @update:model-value="$emit('update:theme', $event)" /><slot /></div>
    </aside>
    <nav class="mobile-nav" aria-label="Navigation mobile">
      <RouterLink v-for="item in mobileLinks" :key="item.label" :to="item.to" active-class="is-active" @click="open = false"><AppIcon :name="item.icon" /><span>{{ item.label }}</span></RouterLink>
    </nav>
  </div>
</template>
<script>
import { RouterLink } from 'vue-router'
import ThemeToggle from '../ui/ThemeToggle.vue'
import AppIcon from '../ui/AppIcon.vue'
export default {
  name: 'AppSidebar', components: { ThemeToggle, AppIcon, RouterLink },
  props: { demo: Boolean, organizationAccess: { type: Boolean, default: false }, role: { type: String, required: true }, theme: { type: String, required: true }, space: { type: String, required: true }, userId: { type: [Number, String], default: null } },
  emits: ['update:theme'],
  data() { return { open: false } },
  watch: { '$route.fullPath'() { this.open = false } },
  computed: {
    accountLink() { return { label: 'Mon compte', icon: 'users', to: { name: 'profile' } } },
    hoursLink() { return { label: 'Mes heures', icon: 'clock', to: this.userId ? { name: 'workingTimes', params: { userID: this.userId } } : { name: 'overview' } } },
    primaryLinks() {
      if (this.role === 'manager') return [{ label: 'Mon équipe', icon: 'users', to: { name: 'team' } }, { label: 'Planning d’équipe', icon: 'calendar', to: { name: 'teamPlanning' } }]
      if (this.role === 'administrator') return [this.organizationAccess ? { label: 'Administration Gotham', icon: 'users', to: { name: 'organization' } } : { label: 'Paie du mois', icon: 'check-circle', to: { name: 'payroll' } }, { label: 'Équipes et droits', icon: 'shield', to: { name: 'rights' } }]
      return [{ label: 'Aujourd’hui', icon: 'sun', to: { name: 'overview' } }, this.hoursLink, { label: 'Mon planning', icon: 'calendar', to: { name: 'planning' } }]
    },
    links() {
      const extra = this.role === 'administrator' ? [
        ...(this.organizationAccess ? [{ label: 'Paie du mois', icon: 'check-circle', to: { name: 'payroll' } }] : []),
        ...(!this.demo ? [{ label: 'Utilisateurs et rôles', icon: 'shield', to: { name: 'adminUsers' } }, { label: 'Équipes', icon: 'users', to: { name: 'adminTeams' } }] : []),
      ] : this.role === 'manager' && !this.demo ? [{ label: 'Mes équipes', icon: 'users', to: { name: 'adminTeams' } }] : []
      if (this.role !== 'employee' && this.userId) extra.push({ label: 'Mon pointage', icon: 'clock', to: { name: 'clock', params: { userid: this.userId } } }, this.hoursLink)
      return [...this.primaryLinks, ...extra, this.accountLink]
    },
    mobileLinks() { return [...this.primaryLinks, this.accountLink] },
    homeRoute() { return this.primaryLinks[0].to },
  },
}
</script>
<style scoped>
.sidebar { position: sticky; top: 0; display: flex; flex-direction: column; min-height: 100vh; padding: 32px 18px 24px; background: var(--side-bg); color: var(--side-ink); }
.brand { font-size: 21px; font-weight: 700; letter-spacing: -.04em; color: inherit; text-decoration: none; }
.space { margin: 22px 10px 30px; font-size: 12px; color: var(--side-muted); overflow-wrap: anywhere; }
.nav { display: flex; flex-direction: column; gap: 7px; }
.nav-link { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-radius: 999px; color: inherit; text-decoration: none; font-size: 13px; font-weight: 600; }
.nav-link svg { width: 18px; height: 18px; flex-shrink: 0; }
.nav-link:hover { background: var(--side-well); }
.nav-link.is-active { background: var(--side-active-bg); color: var(--side-active-ink); }
.settings { margin-top: auto; padding: 32px 0 0; }
.mobile-header, .mobile-nav, .menu-backdrop { display: none; }
@media (max-width: 900px) {
 .mobile-header { display: flex; align-items: center; justify-content: space-between; padding: 15px 16px; background: var(--surface); border-bottom: 1px solid var(--border); color: var(--title); }
 .sidebar { position: fixed; z-index: 51; inset: 0 auto 0 0; width: min(300px, 85vw); min-height: 100dvh; height: 100dvh; overflow-y: auto; visibility: hidden; transform: translateX(-100%); transition: transform .2s, visibility .2s; }
 .sidebar.is-open { visibility: visible; transform: translateX(0); }
 .menu-backdrop { display: block; position: fixed; inset: 0; z-index: 50; border: 0; background: rgba(0,0,0,.35); }
 .mobile-nav { display: flex; justify-content: space-around; position: fixed; z-index: 40; bottom: 0; left: 0; right: 0; padding: 10px 4px calc(10px + env(safe-area-inset-bottom)); background: var(--surface); border-top: 1px solid var(--border); }
 .mobile-nav a { display: flex; flex: 1; flex-direction: column; align-items: center; gap: 5px; padding: 3px; text-align: center; color: var(--text-muted); text-decoration: none; font-size: 10px; }
 .mobile-nav svg { width: 21px; height: 21px; }
 .mobile-nav .is-active { color: var(--title); font-weight: 700; }
}
.mobile-header { gap: 8px; flex-wrap: wrap; }
@media (max-width: 450px) { .mobile-theme-controls { order: 3; width: 100%; justify-content: center; } }
</style>
