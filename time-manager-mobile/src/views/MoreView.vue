<template>
  <PageHeader :title="$t('Plus')" :eyebrow="name" />
  <nav class="card" :aria-label="$t('Autres pages')">
    <ul class="list flush">
      <li v-for="l in links" :key="l.route">
        <RouterLink class="row member-link" :to="{ name: l.route }">
          <span><strong>{{ l.label }}</strong><br><span class="small muted">{{ l.hint }}</span></span>
          <span aria-hidden="true">›</span>
        </RouterLink>
      </li>
    </ul>
  </nav>
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import { MORE_BY_ROLE } from '@/components/navigation/menu.js'
import { app } from '@/services/appState.js'
import { displayName } from '@/ui/format.js'

// Les pages qui ne tiennent pas dans les cinq onglets du bas.
export default {
  name: 'MoreView',
  components: { PageHeader },
  computed: {
    name: () => displayName(app.user),
    links: () => MORE_BY_ROLE[app.user?.role] ?? MORE_BY_ROLE.employee,
  },
}
</script>
