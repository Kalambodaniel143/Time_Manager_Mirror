<template>
  <details class="card fold">
    <summary>{{ $t('Proposer un échange de garde') }}</summary>
    <form class="form-grid" @submit.prevent="send">
      <p class="small muted">{{ $t('Le collègue doit accepter, puis un responsable valide l’échange.') }}</p>
      <label for="swap-mine">{{ $t('Ma garde') }}</label>
      <select id="swap-mine" v-model="mineId" required>
        <option v-for="s in mine" :key="s.id" :value="s.id">{{ label(s) }}</option>
      </select>
      <label for="swap-target">{{ $t('Contre la garde de') }}</label>
      <select id="swap-target" v-model="targetId" required :disabled="!targets.length">
        <option v-for="s in targets" :key="s.id" :value="s.id">{{ who(s) }} · {{ label(s) }}</option>
      </select>
      <label for="swap-reason">{{ $t('Motif') }}</label>
      <textarea id="swap-reason" v-model.trim="reason" rows="2" maxlength="500" required />
      <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
      <button type="submit" :disabled="busy || !mineId || !targetId">{{ $t('Envoyer la proposition') }}</button>
    </form>
  </details>

  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!swaps.length" :empty-text="$t('Aucun échange en cours.')" @retry="load">
    <ul class="list card scroll-box">
      <li v-for="s in swaps" :key="s.id" class="form-grid">
        <p class="row"><strong>{{ title(s) }}</strong><StatusBadge :status="s.status" /></p>
        <p v-if="s.reason" class="small muted">{{ s.reason }}</p>
        <div v-if="s.status === 'pending' && askedToMe(s)" class="request-actions">
          <button type="button" :disabled="busy" @click="consent(s, true)">{{ $t('Accepter') }}</button>
          <button type="button" class="btn-outline" :disabled="busy" @click="consent(s, false)">{{ $t('Refuser') }}</button>
        </div>
      </li>
    </ul>
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import DataState from '@/components/common/DataState.vue'
import StatusBadge from '@/components/common/StatusBadge.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { act, api, read } from '@/services/workforce.js'
import { isFuture, planRange, shiftsOf } from '@/ui/plans.js'
import { personName } from '@/ui/people.js'
import { SHIFT_KINDS } from '@/ui/statusLabels.js'
import { dayMonth, hhmm } from '@/ui/format.js'

// Échanges de gardes (GET/POST /shift-swaps, accord du collègue par /consent).
export default {
  name: 'SwapsPanel',
  components: { DataState, StatusBadge },
  mixins: [loadable],
  data: () => ({ swaps: [], shifts: [], mineId: null, targetId: null, reason: '', busy: false, message: '', ok: false }),
  computed: {
    mine() { return this.shifts.filter((s) => s.user_id === app.user.id && isFuture(s)) },
    targets() {
      const chosen = this.shifts.find((s) => s.id === this.mineId)
      return chosen ? this.shifts.filter((s) => s.plan.id === chosen.plan.id && s.user_id !== app.user.id && isFuture(s)) : []
    },
  },
  created() { this.load() },
  methods: {
    label: (s) => `${dayMonth(s.start)} ${hhmm(s.start)}–${hhmm(s.end)} · ${SHIFT_KINDS[s.kind] ?? s.kind}`,
    who(s) { return personName(s, s.plan.members) },
    shift(id) { return this.shifts.find((s) => s.id === id) },
    title(s) {
      const [a, b] = [s.shift ?? this.shift(s.shift_id), s.target_shift ?? this.shift(s.target_shift_id)]
      return a && b ? `${this.label(a)} ↔ ${this.label(b)}` : t('Échange n° {0}', [s.id])
    },
    askedToMe(s) { return [s.target_user_id, s.target_shift?.user_id, this.shift(s.target_shift_id)?.user_id].includes(app.user.id) },
    async load() {
      const { from, to } = planRange(4)
      const plans = await read('plans:swap', () => api.getPlans(from, to)).catch(() => null)
      this.shifts = shiftsOf(plans?.data)
      this.swaps = (await this.run(() => read('swaps', () => api.getSwaps()))) ?? []
    },
    async attempt(task, done) {
      this.busy = true
      try { await act(task); [this.ok, this.message] = [true, done]; await this.load() } catch (e) { [this.ok, this.message] = [false, e.message] }
      finally { this.busy = false }
    },
    send() { this.attempt(() => api.proposeSwap(this.mineId, this.targetId, this.reason), t('Proposition envoyée à votre collègue.')) },
    consent(swap, accepted) { this.attempt(() => api.consentSwap(swap.id, accepted), accepted ? t('Accord envoyé au responsable.') : t('Échange refusé.')) },
  },
}
</script>
