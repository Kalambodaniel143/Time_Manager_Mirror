<template>
  <div class="jonas-marker" :class="{ 'is-inline': inline }" role="note">
    <span class="jonas-badge">
      <AppIcon name="wrench" />
      À implémenter · Jonas (clocks)
    </span>
    <p class="jonas-title">{{ title }}</p>
    <p v-if="$slots.default" class="jonas-text"><slot /></p>
  </div>
</template>

<script>
import AppIcon from './AppIcon.vue'

export default {
  name: 'JonasMarker',

  components: { AppIcon },

  props: {
    title: { type: String, required: true },
    inline: { type: Boolean, default: false },
  },
}
</script>

<style scoped>
.jonas-marker {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
  padding: 18px 20px;
  background: repeating-linear-gradient(-45deg, var(--surface), var(--surface) 10px, var(--surface-muted) 10px, var(--surface-muted) 20px);
  border: 2px dashed var(--orange);
  border-radius: var(--radius);
  color: var(--text);
}

.jonas-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 10px;
  background: var(--orange);
  color: #ffffff;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.jonas-title {
  font-size: 15px;
  font-weight: 700;
}

.jonas-text {
  font-size: 13.5px;
  color: var(--text-muted);
}

.jonas-marker.is-inline {
  flex-direction: row;
  flex-wrap: wrap;
  align-items: center;
  padding: 10px 14px;
}

.jonas-marker.is-inline .jonas-title {
  font-size: 14px;
}
</style>
