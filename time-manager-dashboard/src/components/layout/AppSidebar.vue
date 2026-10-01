<template>
  <div class="sidebar-shell">
    <div class="mobile-bar">
      <span class="brand-name">Time Manager</span>
      <button class="btn btn-on-dark btn-sm" type="button" :aria-expanded="open" aria-controls="sidebar" @click="open = !open">
        {{ open ? 'Fermer' : 'Menu' }}
      </button>
    </div>

    <aside id="sidebar" class="sidebar" :class="{ 'is-open': open }">
      <span class="deco deco-a" aria-hidden="true"></span>
      <span class="deco deco-b" aria-hidden="true"></span>

      <RouterLink class="brand" :to="homeRoute" @click="open = false">
        <span class="brand-name">Time Manager</span>
      </RouterLink>
      <p class="space">{{ space }}</p>

      <nav class="nav" aria-label="Navigation principale">
        <RouterLink
          v-for="item in links"
          :key="item.label"
          class="nav-link"
          :to="item.to"
          active-class="is-active"
          exact-active-class="is-active"
          @click="open = false"
        >
          <AppIcon :name="item.icon" />
          {{ item.label }}
        </RouterLink>
      </nav>

      <div class="settings">
        <p class="settings-label">Affichage</p>
        <SegmentedControl :model-value="theme" :options="themeOptions" label="Affichage" @update:model-value="$emit('update:theme', $event)" />

        <p class="settings-label">Démo · voir en tant que</p>
        <SegmentedControl :model-value="role" :options="roleOptions" label="Voir en tant que" @update:model-value="$emit('update:role', $event)" />

        <slot />
      </div>
    </aside>
  </div>
</template>

<script>
import { RouterLink } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import SegmentedControl from '../ui/SegmentedControl.vue'

const THEME_OPTIONS = [
  { value: 'light', label: 'Clair' },
  { value: 'night', label: 'Nuit' },
  { value: 'contrast', label: 'Contraste' },
]

const ROLE_OPTIONS = [
  { value: 'employee', label: 'Employé' },
  { value: 'manager', label: 'Manager' },
  { value: 'admin', label: 'Admin' },
]

export default {
  name: 'AppSidebar',

  components: { AppIcon, RouterLink, SegmentedControl },

  props: {
    role: { type: String, required: true },
    theme: { type: String, required: true },
    space: { type: String, required: true },
    userId: { type: [Number, String], default: null },
  },

  emits: ['update:theme', 'update:role'],

  data() {
    return {
      open: false,
      themeOptions: THEME_OPTIONS,
      roleOptions: ROLE_OPTIONS,
    }
  },

  computed: {
    links() {
      if (this.role === 'manager') {
        return [
          { label: 'Mon équipe', icon: 'users', to: { name: 'team' } },
          { label: 'Planning d’équipe', icon: 'calendar', to: { name: 'teamPlanning' } },
        ]
      }

      if (this.role === 'admin') {
        return [
          { label: 'Paie du mois', icon: 'check-circle', to: { name: 'payroll' } },
          { label: 'Équipes et droits', icon: 'shield', to: { name: 'rights' } },
        ]
      }

      const hours = this.userId ? { name: 'workingTimes', params: { userID: this.userId } } : { name: 'overview' }
      return [
        { label: 'Aujourd’hui', icon: 'sun', to: { name: 'overview' } },
        { label: 'Mes heures', icon: 'clock', to: hours },
        { label: 'Mon planning', icon: 'calendar', to: { name: 'planning' } },
      ]
    },

    homeRoute() {
      return this.links[0].to
    },
  },
}
</script>

<style scoped>
.sidebar {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  width: 284px;
  height: 100vh;
  padding: 40px 21px 26px;
  overflow: hidden auto;
  background: var(--side-bg);
  color: var(--side-ink);
}

.deco {
  position: absolute;
  background: var(--side-deco);
}

.deco-a {
  top: 0;
  right: 0;
  width: 58px;
  height: 34px;
}

.deco-b {
  top: 34px;
  right: 58px;
  width: 34px;
  height: 34px;
}

.brand {
  position: relative;
  z-index: 1;
  padding-left: 9px;
  color: inherit;
  text-decoration: none;
}

.brand-name {
  font-family: var(--display);
  font-size: 34px;
  line-height: 1;
  text-transform: uppercase;
}

.brand-name::after {
  content: '';
  display: inline-block;
  width: 10px;
  height: 3px;
  margin-left: 2px;
  background: var(--orange);
}

.space {
  margin: 28px 0 24px 9px;
  font-size: 14px;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}

.space::before {
  content: '< ';
  color: var(--mint);
}

.space::after {
  content: ' />';
  color: var(--mint);
}

.nav {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-link {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 13px 16px;
  border-radius: var(--radius-sm);
  color: var(--side-ink);
  font-size: 16.5px;
  font-weight: 600;
  text-decoration: none;
}

.nav-link svg {
  width: 24px;
  height: 24px;
}

.nav-link:hover:not(.is-active) {
  background: rgba(255, 255, 255, 0.1);
}

.nav-link.is-active {
  background: var(--side-active-bg);
  color: var(--side-active-ink);
}

.settings {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: auto;
  padding-top: 32px;
}

.settings-label {
  margin: 10px 0 4px 8px;
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.settings :deep(.user-card) {
  margin-top: 16px;
}

.mobile-bar {
  display: none;
}

@media (max-width: 900px) {
  .mobile-bar {
    position: sticky;
    top: 0;
    z-index: 40;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 14px 16px;
    background: var(--side-bg);
    color: var(--side-ink);
  }

  .mobile-bar .brand-name {
    font-size: 26px;
  }

  .sidebar {
    position: fixed;
    top: 58px;
    left: 0;
    z-index: 39;
    width: 100%;
    height: calc(100vh - 58px);
    padding-top: 20px;
    transform: translateX(-100%);
    transition: transform 0.2s ease;
  }

  .sidebar.is-open {
    transform: none;
  }

  .sidebar .brand,
  .deco {
    display: none;
  }

  .space {
    margin-top: 0;
  }
}
</style>
