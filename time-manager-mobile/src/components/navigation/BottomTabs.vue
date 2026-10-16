<template>
  <nav class="bottom-tabs" :aria-label="$t('Navigation principale')">
    <RouterLink v-for="tab in tabs" :key="tab.route" :to="{ name: tab.route }"
      :class="{ 'router-link-active': tab.route === 'more' && fromMore }">
      <component :is="tab.icon" :size="22" aria-hidden="true" />
      <span>{{ tab.label }}</span>
    </RouterLink>
  </nav>
</template>

<script>
import { MORE_BY_ROLE, TABS_BY_ROLE } from './menu.js'
import { app } from '@/services/appState.js'

export default {
  name: 'BottomTabs',
  computed: {
    tabs: () => TABS_BY_ROLE[app.user?.role] ?? TABS_BY_ROLE.employee,
    // Une page ouverte depuis « Plus » (et absente des onglets) garde « Plus » allumé.
    fromMore() {
      const name = this.$route.name
      return !this.tabs.some((t) => t.route === name) && (MORE_BY_ROLE[app.user?.role] ?? []).some((l) => l.route === name)
    },
  },
}
</script>
