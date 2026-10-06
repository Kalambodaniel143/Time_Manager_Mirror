<template>
  <nav class="bottom-tabs" aria-label="Navigation principale">
    <RouterLink v-for="tab in tabs" :key="tab.route" :to="{ name: tab.route }">
      <AppIcon :name="tab.icon" />
      <span>{{ tab.label }}</span>
    </RouterLink>
  </nav>
</template>

<script>
import AppIcon from '@shared/components/ui/AppIcon.vue'

export default {
  name: 'BottomTabs',
  components: { AppIcon },
  data() {
    return {
      tabs: [
        { route: 'clock', label: 'Pointage', icon: 'clock' },
        { route: 'hours', label: 'Mes heures', icon: 'calendar' },
        { route: 'planning', label: 'Planning', icon: 'calendar' },
        { route: 'profile', label: 'Profil', icon: 'users' },
      ],
    }
  },
}
</script>
