<template>
  <section class="card unavailable" role="status">
    <h2 class="card-title">{{ title }}</h2>
    <p class="muted">{{ text }}</p>
  </section>
</template>

<script>
export default {
  name: 'UnavailableFeature',
  props: { title: { type: String, required: true }, text: { type: String, required: true } },
}
</script>

<style scoped>
.unavailable { display: flex; flex-direction: column; gap: 12px; padding: 24px; }
</style>
