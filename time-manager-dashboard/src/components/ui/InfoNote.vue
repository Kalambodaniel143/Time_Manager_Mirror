<template>
  <aside class="info-note" :class="{ 'is-flat': flat }">
    <span class="info-badge" aria-hidden="true">
      <AppIcon :name="icon" />
    </span>
    <p class="info-title">{{ title }}</p>
    <p class="info-text"><slot /></p>
  </aside>
</template>

<script>
import AppIcon from './AppIcon.vue'

export default {
  name: 'InfoNote',

  components: { AppIcon },

  props: {
    icon: { type: String, default: 'shield' },
    title: { type: String, required: true },
    flat: { type: Boolean, default: false },
  },
}
</script>

<style scoped>
.info-note {
  position: relative;
  margin: 18px 0 0 12px;
  padding: 20px 22px 22px 50px;
  background: var(--brand-soft);
  border-bottom: 4px solid var(--border);
  border-radius: 2px;
}

.info-badge {
  position: absolute;
  top: -18px;
  left: -12px;
  display: grid;
  place-items: center;
  width: 42px;
  height: 42px;
  background: var(--brand);
  color: var(--on-brand);
  border-radius: 50%;
  font-size: 20px;
}

.info-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--title);
}

.info-text {
  margin-top: 6px;
  font-size: 15.5px;
  line-height: 1.6;
  color: var(--text);
}

.info-note.is-flat {
  margin: 0;
  padding: 16px 20px 16px 54px;
  border-bottom: none;
}

.info-note.is-flat .info-badge {
  top: 16px;
  left: 18px;
  width: 24px;
  height: 24px;
  background: none;
  color: var(--title);
  font-size: 22px;
}

.info-note.is-flat .info-text {
  margin-top: 2px;
  font-size: 14px;
}
</style>
