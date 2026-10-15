<template>
  <header class="page-header">
    <div class="page-heading">
      <p class="eyebrow">{{ eyebrow }}</p>
      <h1 class="page-title">{{ title }}</h1>
    </div>
    <div v-if="$slots.default" class="page-actions">
      <slot />
    </div>
  </header>
</template>

<script>
export default {
  name: 'PageHeader',

  props: {
    eyebrow: { type: String, required: true },
    title: { type: String, required: true },
  },
}
</script>

<style scoped>
.page-header {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 26px;
}

.page-title {
  margin-top: 8px;
}

.page-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  padding-bottom: 4px;
}
</style>
