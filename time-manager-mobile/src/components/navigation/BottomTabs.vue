<template>
  <nav class="bottom-tabs" aria-label="Navigation principale">
    <RouterLink v-for="tab in tabs" :key="tab.route" :to="{ name: tab.route }">
      <component :is="tab.icon" :size="22" aria-hidden="true" />
      <span>{{ tab.label }}</span>
    </RouterLink>
  </nav>
</template>

<script>
import { TABS_BY_ROLE } from './menu.js'
import { app } from '@/services/appState.js'

export default {
  name: 'BottomTabs',
  computed: {
    tabs: () => TABS_BY_ROLE[app.user?.role] ?? TABS_BY_ROLE.employee,
  },
}
</script>
