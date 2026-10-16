<template>
  <section class="card form-grid">
    <h2>{{ $t('Ma semaine') }}</h2>
    <SegmentedTabs v-model="offset" :options="weeks" :label="$t('Semaine')" />
    <p v-if="sheet" class="row small">{{ $t('État de la feuille') }} <StatusBadge :status="sheet.status" /></p>
    <p v-if="sheet?.reason" class="small muted">{{ $t('Motif : {0}', [sheet.reason]) }}</p>
    <label for="week-note">{{ $t('Note pour mon responsable') }}</label>
    <textarea id="week-note" v-model="note" rows="4" maxlength="2000" :disabled="locked"
      :placeholder="$t('Ex. : intervention prolongée mardi soir')" />
    <p v-if="locked" class="small muted">{{ $t('Semaine validée ou clôturée : la note ne peut plus changer.') }}</p>
    <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
    <button type="button" :disabled="busy || locked" @click="save">{{ $t('Enregistrer la note') }}</button>
  </section>
</template>

<script>
import { t } from '@/i18n/index.js'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import StatusBadge from '@/components/common/StatusBadge.vue'
import { app } from '@/services/appState.js'
import { act, api } from '@/services/workforce.js'
import { weekKey, weekLabel } from '@/ui/weeks.js'

// Note hebdomadaire (GET/PUT /users/:id/week-notes/:lundi), lue par le responsable qui valide.
export default {
  name: 'WeekNote',
  components: { SegmentedTabs, StatusBadge },
  data: () => ({ offset: 0, note: '', sheet: null, busy: false, message: '', ok: false }),
  computed: {
    weeks: () => [-1, 0].map((o) => ({ value: o, label: weekLabel(weekKey(o)) })),
    locked() { return ['validated', 'closed'].includes(this.sheet?.status) },
  },
  watch: { offset: { immediate: true, handler() { this.load() } } },
  methods: {
    async load() {
      this.message = ''
      try {
        this.sheet = await act(() => api.getWeekNote(app.user.id, weekKey(this.offset)))
        this.note = this.sheet?.note ?? ''
      } catch (e) { Object.assign(this, { sheet: null, note: '', ok: false, message: e.message }) }
    },
    async save() {
      this.busy = true
      try {
        this.sheet = await act(() => api.saveWeekNote(app.user.id, weekKey(this.offset), this.note)) ?? this.sheet
        Object.assign(this, { ok: true, message: t('Note enregistrée.') })
      } catch (e) { Object.assign(this, { ok: false, message: e.message }) } finally { this.busy = false }
    },
  },
}
</script>
