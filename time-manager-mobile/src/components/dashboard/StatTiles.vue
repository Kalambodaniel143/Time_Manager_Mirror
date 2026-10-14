<template>
  <section class="card kpis" :aria-label="label">
    <div v-if="hero" class="kpi-hero">
      <span><span class="kpi-label">{{ heroTile.label }}</span><span v-if="heroTile.hint" class="kpi-hint">{{ heroTile.hint }}</span></span>
      <strong class="kpi-hero-value">{{ heroTile.value }}</strong>
    </div>
    <dl class="kpi-grid" :class="{ three: compact }">
      <div v-for="tile in rest" :key="tile.label" class="kpi">
        <dt class="kpi-label">{{ tile.label }}</dt>
        <dd class="kpi-value">{{ tile.value }}</dd>
      </div>
    </dl>
  </section>
</template>

<script>
import { t } from '@/i18n/index.js'
// Chiffres clés dans une seule carte : un chiffre principal (hero) puis les autres en grille.
// tiles = [{ label, value, hint? }] ; avec hero, la première tuile devient le chiffre principal.
export default {
  name: 'StatTiles',
  props: {
    tiles: { type: Array, required: true },
    hero: Boolean,
    compact: Boolean, // trois chiffres par ligne au lieu de deux
    label: { type: String, default: t('Chiffres clés') },
  },
  computed: {
    rest() { return this.hero ? this.tiles.slice(1) : this.tiles },
    heroTile() { return this.tiles[0] },
  },
}
</script>
