<template>
  <section class="card form-grid">
    <h2>{{ $t('Par agent') }}</h2>
    <label for="pay-search" class="sr-only">{{ $t('Rechercher') }}</label>
    <input id="pay-search" v-model.trim="search" type="search" :placeholder="$t('Rechercher un agent')" />
    <ul class="list flush scroll-box">
      <li v-for="r in filtered" :key="r.id">
        <button type="button" class="pay-agent" :aria-expanded="open === r.id" @click="open = open === r.id ? null : r.id">
          <span><strong>{{ r.name }}</strong><br>
            <span class="small muted">{{ r.team }} · {{ r.days > 1 ? $t('{0} jours travaillés', [r.days]) : $t('{0} jour travaillé', [r.days]) }}</span></span>
          <strong class="pay-total" :class="{ muted: !r.total }">{{ fmt(r.total) }}</strong>
        </button>
        <dl v-if="open === r.id" class="pay-detail">
          <div v-for="c in CATEGORIES" :key="c"><dt><span class="cat-tag" :class="`cat-${c}`">{{ labels[c] }}</span></dt><dd>{{ fmt(r[c]) }}</dd></div>
        </dl>
      </li>
    </ul>
  </section>
</template>

<script>
import { CATEGORIES } from '@/ui/payroll.js'

// Heures de chaque agent ; un appui déplie le détail par catégorie.
export default {
  name: 'PayAgents',
  props: { rows: { type: Array, required: true }, labels: { type: Object, required: true }, fmt: { type: Function, required: true } },
  data: () => ({ CATEGORIES, search: '', open: null }),
  computed: {
    filtered() {
      const q = this.search.toLowerCase()
      return this.rows.filter((r) => `${r.name} ${r.email} ${r.team}`.toLowerCase().includes(q))
    },
  },
}
</script>
