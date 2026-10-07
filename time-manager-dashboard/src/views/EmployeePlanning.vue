<template>
 <div class="planning page-stack">
  <PageHeader :eyebrow="rangeLabel" title="Mon planning"><button class="btn btn-outline" type="button" @click="swapOpen = true">Demander un échange de garde</button></PageHeader>
  <p class="demo-notice">Planning d’exemple · vos affectations réelles et les dates de publication restent à confirmer auprès de votre responsable.</p>
  <div class="week-tabs" aria-label="Semaine du planning"><button v-for="(week, index) in weeks" :key="week.label" class="btn btn-outline" :class="{ 'is-selected': selectedWeek === index }" :aria-pressed="selectedWeek === index" type="button" @click="selectedWeek = index">{{ week.label }}</button></div>
  <section v-for="(week, index) in weeks" :key="week.label" class="week-section" :class="{ 'mobile-hidden': selectedWeek !== index }"><h2 class="card-title">{{ week.label }}</h2><div class="week-grid"><article v-for="day in week.days" :key="day.key" class="card day" :class="{ 'is-rest': day.kind === 'rest', 'is-today': day.isToday }"><strong>{{ day.label }}</strong><div class="day-details"><span v-if="day.kind === 'rest'" class="muted">Repos</span><HourTag v-else :kind="day.kind" /><span v-if="day.isToday" class="field-hint">Aujourd’hui</span><p v-if="day.shift" class="num">{{ day.shift.from }} – {{ day.shift.to }}</p></div></article></div></section>
  <div class="bottom-grid"><section class="card section-card"><h2 class="card-title">Gardes de nuit et d’astreinte</h2><ul class="shift-list"><li v-for="day in constrainedDays" :key="day.key"><span>{{ day.fullLabel }}</span><span>{{ day.shift.from }} – {{ day.shift.to }}</span><HourTag :kind="day.kind" /></li></ul></section><section class="card section-card"><h2 class="card-title">Des nuits espacées</h2><p class="night-count num">{{ nights }} nuits</p><p class="muted">sur deux semaines · seuil de {{ maxNights }} nuits consécutives.</p><p class="field-hint">Les heures de nuit sont distinguées des heures supplémentaires.</p></section></div>
  <section v-if="myRequests.length" class="card section-card"><h2 class="card-title">Mes demandes d’échange</h2><article v-for="item in myRequests" :key="item.id" class="swap-status"><strong>{{ item.day }}</strong><p>{{ item.reason }}</p><span class="pill" :class="item.status === 'pending' ? 'pill-warn' : 'pill-ok'">{{ statuses[item.status] }}</span></article></section>
  <ModalDialog v-if="swapOpen" title="Demander un échange de garde" id="swap-title" :busy="false" @close="swapOpen = false"><p>Cette demande est enregistrée dans la démonstration. Aucune garde réelle ne sera modifiée et aucun message ne sera envoyé.</p><form class="page-stack" @submit.prevent="requestSwap"><label class="field"><span class="field-label">Garde concernée</span><select v-model="swapDay" class="input" required><option value="" disabled>Choisir une garde</option><option v-for="day in workingDays" :key="day.key" :value="day.key">{{ day.fullLabel }} · {{ day.shift.from }}–{{ day.shift.to }}</option></select></label><label class="field"><span class="field-label">Votre demande</span><textarea v-model.trim="swapReason" class="input" rows="3" maxlength="500" required /></label><p v-if="swapError" class="field-error" role="alert">{{ swapError }}</p><button class="btn btn-primary" type="submit">Enregistrer la demande</button></form></ModalDialog>
 </div>
</template>
<script>
import HourTag from '../components/ui/HourTag.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import ModalDialog from '../components/ui/ModalDialog.vue'
import { employeePlan, org, requestShiftSwap } from '../services/orgService'
import { auth } from '../stores/auth'
import { toDateInput } from '../utils/date'
import { formatRange } from '../utils/hours'
export default {
 name: 'EmployeePlanning', components: { HourTag, PageHeader, ModalDialog }, props: { now: { type: Date, required: true } }, emits: ['tour'],
 data() { return { selectedWeek: 0, swapOpen: false, swapDay: '', swapReason: '', swapError: '', statuses: { pending: 'En attente', accepted: 'Examinée · échange à organiser', rejected: 'Refusée' } } },
 computed: {
  days() { return employeePlan(this.now).map(day => ({ ...day, key: toDateInput(day.date), label: day.date.toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' }), fullLabel: day.date.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' }) })) },
  weeks() { return [0, 7].map(offset => ({ days: this.days.slice(offset, offset + 7), label: formatRange(this.days[offset].date, this.days[offset + 6].date) })) },
  rangeLabel() { return formatRange(this.days[0].date, this.days.at(-1).date) },
  workingDays() { return this.days.filter(day => day.shift) },
  constrainedDays() { return this.days.filter(day => ['night', 'oncall'].includes(day.kind)) },
  maxNights() { return org.rules.maxConsecutiveNights },
  nights() { return this.days.filter(day => day.kind === 'night').length },
  myRequests() { return org.swapRequests.filter(item => item.user_id === auth.user?.id) },
 },
 methods: {
  requestSwap() { try { requestShiftSwap(auth.user, this.swapDay, this.swapReason); this.swapOpen = false; this.swapDay = ''; this.swapReason = ''; this.swapError = '' } catch (error) { this.swapError = error.message } },
 },
}
</script>
<style scoped>
.page-stack { gap: 18px; }
.week-tabs { display: none; }
.week-section > h2 { margin-bottom: 14px; }
.week-grid { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); gap: 10px; }
.day { padding: 16px 10px; display: flex; flex-direction: column; gap: 14px; }
.day > strong { font-size: 12px; }
.day-details { display: flex; flex-direction: column; align-items: flex-start; gap: 8px; }
.day-details p { font-size: 12px; }
.day.is-rest { background: var(--surface-muted); }
.day.is-today { border-color: var(--brand); }
.bottom-grid { display: grid; grid-template-columns: minmax(0, 2fr) minmax(0, 1fr); gap: 20px; }
.shift-list { list-style: none; margin: 14px 0 0; padding: 0; }
.shift-list li { display: flex; gap: 12px; flex-wrap: wrap; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid var(--border); font-size: 13px; }
.night-count { margin: 16px 0 8px; font-size: 30px; font-weight: 700; }
.swap-status { padding: 14px 0; border-bottom: 1px solid var(--border); display: flex; gap: 10px; flex-wrap: wrap; }
@media (max-width: 760px) {
 .week-tabs { display: flex; }
 .week-tabs .is-selected { border-color: var(--brand); background: var(--brand-soft); }
 .mobile-hidden { display: none; }
 .week-grid { display: flex; flex-direction: column; gap: 0; border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden; }
 .day { display: grid; grid-template-columns: 76px minmax(0, 1fr); border: none; border-radius: 0; padding: 14px; border-bottom: 1px solid var(--border); }
 .day > strong { padding-top: 4px; }
 .day-details { gap: 5px; }
 .bottom-grid { grid-template-columns: 1fr; }
}
</style>
