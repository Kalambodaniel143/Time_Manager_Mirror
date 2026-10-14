<template>
  <PageHeader :title="$t('À traiter')" :eyebrow="$t('Décisions de responsable')">
    <template #action><RefreshButton :busy="loading" @refresh="load" /></template>
  </PageHeader>
  <SegmentedTabs v-model="tab" :options="tabs" :label="$t('Type de demande')" />
  <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
  <DataState :loading="loading" :error="error" :empty="!cards.length" :empty-text="$t('Rien à traiter pour le moment.')" @retry="load">
    <div class="scroll-box form-grid">
      <DecisionCard v-for="c in cards" :id="c.id" :key="`${tab}-${c.id}`" :title="c.title" :lines="c.lines"
        :status="c.status" :with-hours="tab === 'absences'" :busy="busy" @decide="decide(c, $event)" />
    </div>
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import RefreshButton from '@/components/common/RefreshButton.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import DataState from '@/components/common/DataState.vue'
import DecisionCard from '@/components/review/DecisionCard.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { act, api, read } from '@/services/workforce.js'
import { getTeams } from '@/services/dataService.js'
import { personName } from '@/ui/people.js'
import { reviewCards } from '@/ui/reviewCards.js'

// Demandes des agents à accepter ou refuser. Personne ne décide sa propre demande (contrôlé aussi par le serveur).
export default {
  name: 'ReviewView',
  components: { PageHeader, RefreshButton, SegmentedTabs, DataState, DecisionCard },
  mixins: [loadable],
  data: () => ({ tab: 'corrections', lists: { corrections: [], absences: [], swaps: [] }, people: [], busy: false, message: '', ok: false }),
  computed: {
    cards() { return reviewCards(this.tab, this.lists[this.tab], (item) => personName(item, this.people, item.requester_id ? 'requester' : 'user')) },
    tabs() {
      const n = (key) => reviewCards(key, this.lists[key], () => '').length
      return [['corrections', t('Corrections')], ['absences', t('Absences')], ['swaps', t('Échanges')]]
        .map(([value, label]) => ({ value, label: n(value) ? `${label} (${n(value)})` : label }))
    },
  },
  created() { this.load() },
  methods: {
    async load() {
      const teams = await getTeams().catch(() => null)
      this.people = (teams?.data ?? []).flatMap((t) => [...t.members, t.manager].filter(Boolean))
      const notMine = (list) => (list ?? []).filter((x) => x.user_id !== app.user.id)
      await this.run(async () => {
        const [corrections, absences, swaps] = await Promise.all([
          read('review:corrections', () => api.getCorrections()), read('review:absences', () => api.getAbsences()), read('review:swaps', () => api.getSwaps()),
        ])
        this.lists = { corrections: notMine(corrections.data), absences: notMine(absences.data), swaps: swaps.data ?? [] }
        return { data: null, stale: corrections.stale }
      })
    },
    async decide(card, { status, reason, hours }) {
      const calls = {
        corrections: () => api.decideCorrection(card.id, status, reason),
        absences: () => api.decideAbsence(card.id, { status, reason, ...(hours !== '' && status === 'approved' ? { payable_hours: String(hours) } : {}) }),
        swaps: () => api.decideSwap(card.id, status, reason),
      }
      this.busy = true
      try {
        await act(calls[this.tab])
        Object.assign(this, { ok: true, message: status === 'approved' ? t('Demande acceptée.') : t('Demande refusée.') })
        await this.load()
      } catch (e) { Object.assign(this, { ok: false, message: e.message }) } finally { this.busy = false }
    },
  },
}
</script>
