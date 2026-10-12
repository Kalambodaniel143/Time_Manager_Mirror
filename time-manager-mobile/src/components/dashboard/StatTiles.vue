<template>
  <dl class="stat-tiles">
    <div v-for="tile in tiles" :key="tile.label" class="card">
      <dt class="muted small">{{ tile.label }}</dt>
      <dd>{{ tile.value }}</dd>
    </div>
  </dl>
</template>

<script>
// Chiffres clés en tuiles : [{ label, value }].
export default {
  name: 'StatTiles',
  props: { tiles: { type: Array, required: true } },
}
</script>
