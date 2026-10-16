<template>
  <section class="card form-grid">
    <h2>{{ $t('Membres et rôles · {0}', [users.length]) }}</h2>
    <p class="small muted">{{ $t('Un appui ouvre le tableau de bord de la personne, son rôle et la suppression du compte.') }}</p>
    <label for="search" class="sr-only">{{ $t('Rechercher') }}</label>
    <input id="search" v-model.trim="search" type="search" :placeholder="$t('Rechercher un nom ou un e-mail')" />
    <p v-if="!filtered.length" class="muted small">{{ $t('Aucun compte trouvé.') }}</p>
    <ul class="list flush scroll-box">
      <li v-for="u in filtered" :key="u.id">
        <RouterLink class="row member-link" :to="{ name: 'member', params: { id: u.id } }">
          <span><strong>{{ displayName(u) }}</strong><br><span class="muted small">{{ u.email }}</span></span>
          <span class="badge">{{ ROLE_LABELS[u.role] ?? u.role }}</span>
        </RouterLink>
      </li>
    </ul>
  </section>
</template>

<script>
import { ROLE_LABELS, displayName } from '@/ui/format.js'

// Comptes de l'organisation, avec recherche (comme « Membres et rôles » sur le web).
export default {
  name: 'MembersList',
  props: { users: { type: Array, required: true } },
  data: () => ({ search: '', ROLE_LABELS }),
  computed: {
    filtered() {
      const q = this.search.toLowerCase()
      return this.users.filter((u) => `${displayName(u)} ${u.email}`.toLowerCase().includes(q))
    },
  },
  methods: { displayName },
}
</script>
