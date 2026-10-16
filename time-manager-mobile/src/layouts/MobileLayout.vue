<template>
  <div class="mobile-layout">
    <SyncBanner />
    <main v-if="user" id="main-content" class="page-content">
      <!-- :key = un autre compte repart d'écrans vides, sans données de l'ancien -->
      <RouterView :key="user.id" />
    </main>
    <BottomTabs />
  </div>
</template>

<script>
import BottomTabs from '@/components/navigation/BottomTabs.vue'
import SyncBanner from '@/components/status/SyncBanner.vue'
import { app } from '@/services/appState.js'

export default {
  name: 'MobileLayout',
  components: { BottomTabs, SyncBanner },
  computed: { user: () => app.user },
}
</script>
