<template>
  <div class="banner" :class="`banner-${tone}`" :role="tone === 'danger' ? 'alert' : 'status'">
    <AppIcon class="banner-icon" :name="tone === 'danger' ? 'alert' : 'warning'" />
    <div class="banner-body">
      <p class="banner-title">{{ title }}</p>
      <p v-if="text" class="banner-text">{{ text }}</p>
    </div>
    <slot />
  </div>
</template>

<script>
import AppIcon from './AppIcon.vue'

export default {
  name: 'AlertBanner',

  components: { AppIcon },

  props: {
    tone: { type: String, default: 'warning' },
    title: { type: String, required: true },
    text: { type: String, default: '' },
  },
}
</script>
