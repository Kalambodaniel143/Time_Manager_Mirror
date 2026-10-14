<template>
  <PageHeader :title="$t('Semaines')" :eyebrow="$t('Validation des feuilles')">
    <template #action><RefreshButton :busy="loading" @refresh="load" /></template>
  </PageHeader>
  <SegmentedTabs v-model="offset" :options="weeks" :label="$t('Semaine')" />
  <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!sheets.length" :empty-text="$t('Aucune feuille pour cette semaine.')" @retry="load">
    <ul class="list card scroll-box">
      <li v-for="s in sheets" :key="s.user_id" class="form-grid">
        <label class="row choice">
          <span><input v-model="selected" type="checkbox" :value="s.user_id" :disabled="!selectable(s)" /> {{ name(s) }}</span>
          <StatusBadge :status="s.status" />
        </label>
        <p v-if="s.note" class="small">📝 {{ s.note }}</p>
        <p v-if="s.reason" class="small muted">{{ $t('Motif : {0}', [s.reason]) }}</p>
        <button v-if="s.status !== 'open' || offset < 0" type="button" class="btn-quiet" :disabled="busy || s.user_id === me"
          @click="action(s, s.status === 'open' ? 'close' : 'reopen')">{{ s.status === 'open' ? $t('Clôturer') : $t('Rouvrir') }}</button>
      </li>
    </ul>
    <button type="button" :disabled="busy || !selected.length" @click="validate">{{ $t('Valider la sélection ({0})', [selected.length]) }}</button>
    <p class="small muted">{{ $t('Seules les semaines terminées se valident. Un départ manquant ou une correction en attente bloque la validation.') }}</p>
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import RefreshButton from '@/components/common/RefreshButton.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import DataState from '@/components/common/DataState.vue'
import StatusBadge from '@/components/common/StatusBadge.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { act, api, read } from '@/services/workforce.js'
import { getTeams } from '@/services/dataService.js'
import { personName } from '@/ui/people.js'
import { weekKey, weekLabel } from '@/ui/weeks.js'

// Feuilles hebdomadaires de mon périmètre : valider en groupe, clôturer, rouvrir (jamais la mienne).
export default {
  name: 'WeeksView',
  components: { PageHeader, RefreshButton, SegmentedTabs, DataState, StatusBadge },
  mixins: [loadable],
  data: () => ({ offset: -1, sheets: [], people: [], selected: [], busy: false, message: '', ok: false }),
  computed: {
    me: () => app.user.id,
    weeks: () => [-2, -1, 0].map((o) => ({ value: o, label: weekLabel(weekKey(o)) })),
  },
  watch: { offset() { this.load() } },
  created() { this.load() },
  methods: {
    name(s) { return personName(s, this.people) },
    selectable(s) { return s.status === 'open' && s.user_id !== this.me && this.offset < 0 },
    async load() {
      this.selected = []
      const teams = await getTeams().catch(() => null)
      this.people = (teams?.data ?? []).flatMap((t) => [...t.members, t.manager].filter(Boolean))
      const week = weekKey(this.offset)
      this.sheets = (await this.run(() => read(`weeks:${week}`, () => api.getWeeklySheets(week)))) ?? []
    },
    async attempt(task, done) {
      this.busy = true
      try { await act(task); Object.assign(this, { ok: true, message: done }); await this.load() } catch (e) { Object.assign(this, { ok: false, message: e.message }) }
      finally { this.busy = false }
    },
    validate() { this.attempt(() => api.validateWeeks(weekKey(this.offset), this.selected), t('Semaines validées.')) },
    action(sheet, verb) {
      const reason = window.prompt(verb === 'close' ? t('Motif de la clôture') : t('Motif de la réouverture'))
      if (reason?.trim()) this.attempt(() => api.weekAction(sheet.user_id, weekKey(this.offset), verb, reason.trim()), verb === 'close' ? t('Semaine clôturée.') : t('Semaine rouverte.'))
    },
  },
}
</script>
