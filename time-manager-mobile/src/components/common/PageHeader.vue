<template>
  <header class="page-header">
    <p v-if="eyebrow" class="eyebrow">{{ eyebrow }}</p>
    <h1>{{ title }}</h1>
    <slot />
  </header>
</template>

<script>
export default {
  name: 'PageHeader',
  props: { title: { type: String, required: true }, eyebrow: { type: String, default: '' } },
}
</script>
