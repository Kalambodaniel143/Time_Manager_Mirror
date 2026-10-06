<template>
  <div class="mobile-layout">
    <header class="page-header">
      <p class="brand">Time Manager</p>
      <h1>{{ $route.meta.title }}</h1>
    </header>
    <main id="main-content" class="page-content">
      <RouterView />
    </main>
    <BottomTabs />
  </div>
</template>

<script>
import BottomTabs from '@/components/navigation/BottomTabs.vue'

export default {
  name: 'MobileLayout',
  components: { BottomTabs },
}
</script>
