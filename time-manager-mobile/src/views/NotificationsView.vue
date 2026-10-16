<template>
  <PageHeader :title="$t('Notifications')" :eyebrow="unread ? $t('{0} non lue(s)', [unread]) : $t('Tout est lu')">
    <template #action><RefreshButton :busy="loading" @refresh="load" /></template>
  </PageHeader>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!items.length" :empty-text="$t('Aucune notification.')" @retry="load">
    <SegmentedTabs v-model="filter" :options="filters" :label="$t('Filtrer les notifications')" />
    <button v-if="unread" type="button" class="btn-quiet small mark-all" :disabled="busy" @click="markAll">{{ $t('Tout marquer comme lu') }}</button>
    <p v-if="!shown.length" class="card muted center">{{ filter === 'unread' ? $t('Aucune notification non lue.') : $t('Aucune notification lue.') }}</p>
    <ul v-else class="list card">
      <li v-for="n in shown" :key="n.id">
        <button type="button" class="btn-quiet notification" :class="{ unread: !n.read_at }" @click="markRead(n)">
          <strong>{{ n.title || n.kind || $t('Information') }}</strong>
          <span>{{ n.body || n.message }}</span>
          <span v-if="n.inserted_at || n.created_at" class="small muted">{{ ago(n.inserted_at || n.created_at) }}</span>
        </button>
      </li>
    </ul>
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import RefreshButton from '@/components/common/RefreshButton.vue'
import DataState from '@/components/common/DataState.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import loadable from '@/ui/loadable.js'
import { act, api, read } from '@/services/workforce.js'
import { ago } from '@/ui/format.js'

// Notifications personnelles (publication de planning, décisions…), filtrées lues / non lues.
// Un appui en marque une comme lue ; « Tout marquer comme lu » les traite toutes.
export default {
  name: 'NotificationsView',
  components: { PageHeader, RefreshButton, DataState, SegmentedTabs },
  mixins: [loadable],
  data: () => ({ items: [], filter: 'all', busy: false }),
  computed: {
    unread() { return this.items.filter((n) => !n.read_at).length },
    filters() {
      return [{ value: 'all', label: t('Toutes') }, { value: 'unread', label: `${t('Non lues')} (${this.unread})` },
        { value: 'read', label: t('Lues') }]
    },
    shown() { return this.items.filter((n) => this.filter === 'all' || (this.filter === 'unread') === !n.read_at) },
  },
  created() { this.load() },
  methods: {
    ago,
    async load() { this.items = (await this.run(() => read('notifications', () => api.getNotifications()))) ?? [] },
    async markAll() {
      this.busy = true
      await Promise.all(this.items.filter((n) => !n.read_at).map((n) => this.markRead(n)))
      this.busy = false
    },
    async markRead(n) {
      if (n.read_at) return
      try { await act(() => api.readNotification(n.id)); n.read_at = new Date().toISOString() } catch { /* reste non lue */ }
    },
  },
}
</script>
