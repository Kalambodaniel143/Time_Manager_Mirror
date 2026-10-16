<template>
  <div class="page-stack"><PageHeader :title="$t(&quot;Mon planning&quot;)"><button class="btn btn-outline" :disabled="loading" @click="load">{{ $t("Actualiser") }}</button></PageHeader><p class="field-hint">{{ $t("Gardes publiées par votre responsable. Horaires en UTC ; une journée sans affectation ne signifie pas un congé.") }}</p><label class="field"><span class="field-label">{{ $t("À partir du") }}</span><input v-model="from" class="input" type="date" @change="load" /></label><p v-if="error" class="field-error" role="alert">{{ $t(error) }}</p><p v-if="loading" role="status">{{ $t("Chargement du planning…") }}</p><section v-else-if="!error" class="card section-card page-stack"><h2 class="card-title">{{ $t("Mes prochaines gardes") }}</h2><p v-if="!ownShifts.length" class="muted">{{ $t("Aucune garde publiée sur cette période.") }}</p><article v-for="shift in ownShifts" :key="`${shift.plan_id}-${shift.id}`" class="shift"><div><strong>{{ shift.team }}</strong><p>{{ stamp(shift.start) }} → {{ stamp(shift.end) }} {{ $t("UTC") }}</p><p>{{ shift.place }}</p><HourTag :kind="shift.kind" /></div><button v-if="future(shift) && candidates(shift).length" class="btn btn-outline btn-sm" @click="open(shift)">{{ $t("Proposer un échange") }}</button></article></section><SwapPanel :refresh-key="swapVersion" @changed="load" /><AbsencePanel /><ModalDialog v-if="source" :title="$t(&quot;Proposer un échange de gardes&quot;)" id="request-swap" :busy="busy" @close="source = null"><p>{{ $t("L’accord de votre collègue puis la validation d’un responsable sont nécessaires.") }}</p><form class="page-stack" @submit.prevent="submitSwap"><label class="field"><span class="field-label">{{ $t("Garde du collègue") }}</span><select v-model.number="targetId" class="input" required><option :value="null" disabled>{{ $t("Choisir une garde") }}</option><option v-for="shift in candidates(source)" :key="shift.id" :value="shift.id">{{ shift.name }} · {{ stamp(shift.start) }} {{ $t("UTC") }}</option></select></label><label class="field"><span class="field-label">{{ $t("Motif") }}</span><textarea v-model.trim="reason" class="input" maxlength="500" required /></label><p v-if="dialogError" class="field-error" role="alert">{{ $t(dialogError) }}</p><button class="btn btn-primary" :disabled="busy || !targetId || !reason">{{ $t("Envoyer la proposition") }}</button></form></ModalDialog></div>
</template>
<script>
import { auth } from '../../stores/auth'
import { listPlans, requestSwap } from '../../services/workforceService'
import { toDateInput } from '../../utils/date'
import { addDays } from '../../utils/hours'
import { clockDate } from '../../utils/missingDeparture'
import { formatClockDate } from '../../utils/clockDate'
import PageHeader from '../ui/PageHeader.vue'
import HourTag from '../ui/HourTag.vue'
import ModalDialog from '../ui/ModalDialog.vue'
import AbsencePanel from './AbsencePanel.vue'
import SwapPanel from './SwapPanel.vue'
export default {
  name: 'EmployeePlan', components: { PageHeader, HourTag, ModalDialog, AbsencePanel, SwapPanel },
  data() { return { plans: [], from: toDateInput(new Date()), loading: false, error: '', version: 0, source: null, targetId: null, reason: '', busy: false, dialogError: '', swapVersion: 0 } },
  computed: { shifts() { return this.plans.flatMap(plan => plan.shifts.map(shift => ({ ...shift, plan_id: plan.id, team: plan.team_name, name: plan.members.find(user => user.id === shift.user_id)?.name || `Agent ${shift.user_id}` }))).sort((a,b) => a.start.localeCompare(b.start)) }, ownShifts() { return this.shifts.filter(shift => shift.user_id === auth.user?.id && shift.start.slice(0,10) >= this.from) } },
  created() { this.load() }, beforeUnmount() { this.version += 1 },
  methods: {
    stamp: formatClockDate,
    future(shift) { return clockDate(shift.start) > new Date() },
    candidates(source) { return this.shifts.filter(shift => shift.plan_id === source.plan_id && shift.user_id !== auth.user?.id && this.future(shift) && !['leave', 'rest'].includes(shift.kind)) },
    open(source) { this.source = source; this.reason = ''; this.targetId = null; this.dialogError = '' },
    async load() { const version = ++this.version; this.loading = true; this.error = ''; try { const plans = await listPlans({ from: this.from, to: toDateInput(addDays(new Date(`${this.from}T00:00:00`), 42)) }); if (version === this.version) this.plans = plans } catch (error) { if (version === this.version) this.error = error.message } finally { if (version === this.version) this.loading = false } },
    async submitSwap() { if (this.busy) return; this.busy = true; this.dialogError = ''; try { await requestSwap(this.source.id, this.targetId, this.reason); this.source = null; this.swapVersion += 1 } catch (error) { this.dialogError = error.message } finally { this.busy = false } },
  },
}
</script>
<style scoped>
.shift { display: flex; gap: 16px; justify-content: space-between; align-items: center; border-top: 1px solid var(--border); padding-top: 16px; }
.shift p { margin: 6px 0; }
@media(max-width:760px) { .shift { flex-direction: column; align-items: stretch; } }
</style>
