<template>
  <PageHeader :title="$t('Journal')" :eyebrow="$t('200 dernières actions')">
    <template #action><RefreshButton :busy="loading" @refresh="load" /></template>
  </PageHeader>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!events.length" :empty-text="$t('Aucune action enregistrée.')" @retry="load">
    <label for="audit-search" class="sr-only">{{ $t('Filtrer') }}</label>
    <input id="audit-search" v-model.trim="search" type="search" :placeholder="$t('Filtrer par action ou personne')" />
    <ul class="list card scroll-box">
      <li v-for="e in filtered" :key="e.id">
        <p class="row"><strong>{{ auditLabel(e.action) }}</strong><span class="small muted">{{ when(e) }}</span></p>
        <p class="small muted">{{ personName(e, users, 'actor') }}</p>
      </li>
    </ul>
  </DataState>
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import RefreshButton from '@/components/common/RefreshButton.vue'
import DataState from '@/components/common/DataState.vue'
import loadable from '@/ui/loadable.js'
import { api, read } from '@/services/workforce.js'
import { getUsers } from '@/services/dataService.js'
import { personName } from '@/ui/people.js'
import { ago } from '@/ui/format.js'
import { auditLabel } from '@/ui/auditLabels.js'

// Journal de l'organisation (GET /audit-events) : qui a fait quoi, et quand.
export default {
  name: 'AuditView',
  components: { PageHeader, RefreshButton, DataState },
  mixins: [loadable],
  data: () => ({ events: [], users: [], search: '' }),
  computed: {
    filtered() {
      const q = this.search.toLowerCase()
      return this.events.filter((e) => `${auditLabel(e.action)} ${e.action} ${personName(e, this.users, 'actor')}`.toLowerCase().includes(q))
    },
  },
  created() { this.load() },
  methods: {
    personName, auditLabel,
    when: (e) => (e.inserted_at || e.created_at ? ago(e.inserted_at || e.created_at) : ''),
    async load() {
      this.users = (await getUsers().catch(() => null))?.data ?? []
      this.events = (await this.run(() => read('audit', () => api.getAuditEvents()))) ?? []
    },
  },
}
</script>
