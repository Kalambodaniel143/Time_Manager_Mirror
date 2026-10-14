<template>
  <header class="page-header">
    <div class="page-title">
      <div>
        <p v-if="eyebrow" class="eyebrow">{{ eyebrow }}</p>
        <h1>{{ title }}</h1>
      </div>
      <slot name="action" />
    </div>
    <slot />
  </header>
</template>

<script>
// Titre d'écran : surtitre, titre, action à droite (ex. actualiser), contenu libre dessous.
export default {
  name: 'PageHeader',
  props: { title: { type: String, required: true }, eyebrow: { type: String, default: '' } },
}
</script>
