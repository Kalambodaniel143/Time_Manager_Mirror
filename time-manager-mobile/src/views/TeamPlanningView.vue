<template>
  <PageHeader :title="$t('Planning d’équipe')" :eyebrow="$t('Préparer et publier les gardes')" />
  <label for="team">{{ $t('Équipe') }}</label>
  <select id="team" v-model="teamId">
    <option v-for="t in teams" :key="t.id" :value="t.id">{{ t.name }}</option>
  </select>
  <RangePicker v-model="range" />
  <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt" @retry="load">
    <p v-if="!plansOfTeam.length" class="card muted center">{{ $t('Aucun planning sur cette période.') }}</p>
    <PlanCard v-for="p in plansOfTeam" :key="p.id" :plan="p" :range="range" :busy="busy" @save-shift="saveShift(p, $event)"
      @remove-shift="removeShift(p, $event)" @edit-period="editPeriod(p, $event)" @publish="publish(p)" @remove="removePlan(p)" />
    <details class="card fold">
      <summary>{{ $t('Nouveau planning') }}</summary>
      <PeriodForm :start="range.from" :end="range.to" :label="$t('Créer le brouillon')" :busy="busy || !teamId" @save="createPlan" />
    </details>
  </DataState>
</template>

<script>
import { t } from '@/i18n/index.js'
import PageHeader from '@/components/common/PageHeader.vue'
import DataState from '@/components/common/DataState.vue'
import RangePicker from '@/components/planning/RangePicker.vue'
import PeriodForm from '@/components/planning/PeriodForm.vue'
import PlanCard from '@/components/planning/PlanCard.vue'
import loadable from '@/ui/loadable.js'
import { app } from '@/services/appState.js'
import { act, api, read } from '@/services/workforce.js'
import { getTeams } from '@/services/dataService.js'
import { confirmAction } from '@/native/device.js'
import { findOverlap, planEnd } from '@/ui/plans.js'
import { personName } from '@/ui/people.js'
import { dayMonth, hhmm } from '@/ui/format.js'
import { weekRange } from '@/ui/weeks.js'

// Plannings des équipes que je gère, sur la période choisie : créer, modifier la période,
// gérer les créneaux (sans doublon pour un même agent), publier, supprimer.
// Les agents ne voient que la dernière version publiée ; le serveur vérifie chaque droit.
export default {
  name: 'TeamPlanningView',
  components: { PageHeader, DataState, RangePicker, PeriodForm, PlanCard },
  mixins: [loadable],
  data: () => ({ teams: [], teamId: null, plans: [], range: weekRange(0, 4), busy: false, message: '', ok: false }),
  computed: {
    plansOfTeam() {
      const { from, to } = this.range
      return this.plans.filter((p) => p.team_id === this.teamId && p.start <= to && planEnd(p) >= from)
        .sort((a, b) => a.start.localeCompare(b.start))
    },
  },
  watch: { range() { this.load() } },
  created() { this.load() },
  methods: {
    async load() {
      const teams = (await getTeams().catch(() => null))?.data ?? []
      this.teams = teams.filter((t) => t.manager?.id === app.user.id || app.user.role === 'administrator')
      this.teamId ??= this.teams[0]?.id ?? null
      const { from, to } = this.range
      this.plans = (await this.run(() => read(`plans:team:${from}:${to}`, () => api.getPlans(from, to)))) ?? []
    },
    async attempt(task, done) {
      this.busy = true
      try { await act(task); Object.assign(this, { ok: true, message: done }); await this.load() } catch (e) { Object.assign(this, { ok: false, message: e.message }) }
      finally { this.busy = false }
    },
    createPlan({ start, days }) {
      const clash = this.plans.find((p) => p.team_id === this.teamId && p.start <= planEnd({ start, days }) && planEnd(p) >= start)
      if (clash) { Object.assign(this, { ok: false, message: t('Un planning couvre déjà ces dates ({0} – {1}). Modifiez sa période.', [dayMonth(`${clash.start}T12:00`), dayMonth(`${planEnd(clash)}T12:00`)]) }); return }
      this.attempt(() => api.createPlan(this.teamId, start, days), t('Brouillon créé : ajoutez les créneaux puis publiez.'))
    },
    editPeriod(plan, period) { this.attempt(() => api.updatePlan(plan.id, period, plan.revision), t('Période du planning modifiée.')) },
    // Ajout ou modification d'un créneau, refusé si l'agent a déjà une garde qui chevauche.
    saveShift(plan, { id, shift }) {
      const clash = findOverlap(shift, this.plans, id)
      if (clash) {
        const who = personName(clash, plan.members)
        Object.assign(this, { ok: false, message: t('Doublon : {0} a déjà une garde du {1} {2} au {3} {4}.', [who, dayMonth(clash.start), hhmm(clash.start), dayMonth(clash.end), hhmm(clash.end)]) })
        return
      }
      const body = { ...shift, revision: plan.revision }
      if (id) this.attempt(() => api.updateShift(plan.id, id, body), t('Créneau modifié.'))
      else this.attempt(() => api.addShift(plan.id, body), t('Créneau ajouté au brouillon.'))
    },
    async removeShift(plan, shift) {
      if (await confirmAction(t('Supprimer ce créneau ?'), 'Supprimer')) this.attempt(() => api.deleteShift(plan.id, shift.id, plan.revision), t('Créneau supprimé.'))
    },
    publish(plan) { this.attempt(() => api.publishPlan(plan.id, plan.revision), t('Planning publié : les agents le voient.')) },
    removePlan(plan) {
      const reason = window.prompt('Supprimer ce planning ? Indiquez le motif (les agents sont prévenus).')
      if (reason?.trim()) this.attempt(() => api.deletePlan(plan.id, plan.revision, reason.trim()), t('Planning supprimé.'))
    },
  },
}
</script>
