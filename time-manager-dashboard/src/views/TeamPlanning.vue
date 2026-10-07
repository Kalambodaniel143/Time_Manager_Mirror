<template>
  <div class="team-planning">
    <PageHeader :eyebrow="`${published ? 'Publié' : 'À publier'} · ${rangeLabel}`" title="Planning d’équipe">
      <button class="btn btn-primary" type="button" :disabled="!publishable" :title="blockReason" @click="publish">
        <AppIcon name="calendar" />
        {{ published ? `Publié jusqu’au ${endLabel}` : `Publier jusqu’au ${endLabel}` }}
      </button>
    </PageHeader>

    <p class="demo-notice">Planning d’exemple · les modifications restent dans ce navigateur et aucun agent n’est notifié. Le contrôle mensuel porte sur les jours affichés ; le serveur devra vérifier le mois complet.</p>
    <div class="week-tabs" aria-label="Semaine du planning"><button v-for="(week, index) in weeks" :key="index" class="btn btn-outline" :aria-pressed="selectedWeek === index" type="button" @click="selectedWeek = index">{{ week }}</button></div>
    <label class="agent-select field"><span class="field-label">Afficher la semaine de</span><select v-model="selectedAgent" class="input"><option v-for="row in rows" :key="row.username" :value="row.username">{{ row.name }} · {{ row.unit }}</option></select></label>
    <div class="stack">
      <AlertBanner v-for="alert in alerts" :key="alert.member.username" tone="danger" :title="alert.title" :text="alert.text">
        <button v-if="alert.partner" class="btn btn-on-dark btn-sm" type="button" @click="swap(alert)">
          Échanger le {{ alert.day }} avec {{ alert.partnerFirst }}
        </button>
      </AlertBanner>

      <AlertBanner v-for="message in frequencyAlerts" :key="message" tone="warning" title="Fréquence de nuits à ajuster" :text="message" />
      <PlanGrid :days="visibleDays" :rows="visibleRows" :max-nights="maxNights" :offset="selectedWeek * 7" :selected-agent="selectedAgent" @cycle="cycle" />
      <section v-if="swapRequests.length" class="card section-card"><h2 class="card-title">Demandes d’échange de la démonstration</h2><article v-for="item in swapRequests" :key="item.id" class="swap-request"><strong>{{ item.username }} · {{ item.day }}</strong><p>{{ item.reason }}</p><div><button class="btn btn-outline btn-sm" type="button" @click="resolveSwap(item.id, 'accepted')">Examiner et organiser</button><button class="btn btn-quiet btn-sm" type="button" @click="resolveSwap(item.id, 'rejected')">Refuser</button></div></article></section>

      <p class="legend">
        <HourTag kind="day" />
        <HourTag kind="night" />
        <HourTag kind="oncall" />
        <HourTag kind="leave" />
        <span>
          Seuil de l’équipe : {{ maxNights }} nuits d’affilée, fixé par l’administration. Publication {{ daysAhead }} jours à
          l’avance.
        </span>
      </p>
      <p v-if="!rightGranted" class="field-hint">
        Publication réservée : votre droit « publier le planning » est désactivé par l’administration.
      </p>
    </div>
  </div>
</template>

<script>
import AlertBanner from '../components/ui/AlertBanner.vue'
import AppIcon from '../components/ui/AppIcon.vue'
import HourTag from '../components/ui/HourTag.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import PlanGrid from '../components/manager/PlanGrid.vue'
import {
  canPublish,
  resolveShiftSwap,
  org,
  planAlerts,
  publishPlan,
  setShift,
  swapShifts,
  teamPlanDays,
  teamPlanRows,
} from '../services/orgService'
import { auth } from '../stores/auth'
import { formatRange, longestRun } from '../utils/hours'
import { notify } from '../utils/toast'

const CYCLE = ['day', 'night', 'oncall', 'leave', 'rest']

function dayMonth(date) {
  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' })
}

export default {
  name: 'TeamPlanning',

  components: { AlertBanner, AppIcon, HourTag, PageHeader, PlanGrid },

  data() { return { selectedWeek: 0, selectedAgent: '' } },
  computed: {
    frequencyAlerts() {
      return this.rows.flatMap(row => {
        const messages = []
        if (org.rules.maxNightsPerWeek > 0) [0, 7].forEach(offset => {
          const count = row.shifts.slice(offset, offset + 7).filter(kind => kind === 'night').length
          if (count > org.rules.maxNightsPerWeek) messages.push(`${row.name} : ${count} nuits sur la semaine du ${this.days[offset].getDate()}, seuil ${org.rules.maxNightsPerWeek}.`)
        })
        if (org.rules.maxNightsPerMonth > 0) {
          const months = {}
          row.shifts.forEach((kind, index) => { if (kind === 'night') { const month = this.days[index].getMonth(); months[month] = (months[month] || 0) + 1 } })
          if (Object.values(months).some(count => count > org.rules.maxNightsPerMonth)) messages.push(`${row.name} dépasse déjà le seuil mensuel de ${org.rules.maxNightsPerMonth} nuits sur la période affichée.`)
        }
        return messages
      })
    },
    weeks() { return [0, 7].map(offset => formatRange(this.days[offset], this.days[offset + 6])) },
    visibleDays() { return this.days.slice(this.selectedWeek * 7, this.selectedWeek * 7 + 7) },
    visibleRows() { return this.rows.map(row => ({ ...row, shifts: row.shifts.slice(this.selectedWeek * 7, this.selectedWeek * 7 + 7) })) },
    swapRequests() { return org.swapRequests.filter(item => item.status === 'pending') },
    days() {
      return teamPlanDays()
    },

    rows() {
      return teamPlanRows().map((row) => ({ ...row, run: longestRun(row.shifts, 'night') }))
    },

    maxNights() {
      return org.rules.maxConsecutiveNights
    },

    daysAhead() {
      return org.rules.publishDaysAhead
    },

    published() {
      return org.teamPlan.published
    },

    rangeLabel() {
      return formatRange(this.days[0], this.days[this.days.length - 1])
    },

    endLabel() {
      return this.days[this.days.length - 1].toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })
    },

    alerts() {
      return planAlerts().map((alert) => {
        const first = this.days[alert.run.start]
        const last = this.days[alert.run.start + alert.run.length - 1]
        const swapDay = this.days[alert.index]
        const partnerFirst = alert.partner ? alert.partner.short.split(' ')[0] : ''
        const text = alert.partner
          ? `Le seuil de l’équipe est de ${this.maxNights}. ${alert.partner.short} est de jour le ${swapDay.getDate()} et n’a pas de nuit la veille.`
          : `Le seuil de l’équipe est de ${this.maxNights}. Aucun échange simple : modifiez le planning case par case.`
        return {
          ...alert,
          title: `${alert.member.short} : ${alert.run.length} nuits d’affilée prévues, du ${first.getDate()} au ${dayMonth(last)}`,
          text,
          day: swapDay.getDate(),
          partnerFirst,
        }
      })
    },

    rightGranted() {
      return auth.organizationSession ? ['manager', 'administrator'].includes(auth.user?.role) : auth.user?.role === 'administrator' || canPublish(auth.user?.username?.split('.')[0] || 'lucie')
    },

    publishable() {
      return !this.published && this.alerts.length === 0 && this.frequencyAlerts.length === 0 && this.rightGranted
    },

    blockReason() {
      if (this.published) return 'Planning déjà publié.'
      if (this.alerts.length || this.frequencyAlerts.length) return 'Corrigez les alertes avant de publier.'
      if (!this.rightGranted) return 'Droit de publication désactivé par l’administration.'
      return ''
    },
  },

  methods: {
    resolveSwap(id, status) { resolveShiftSwap(id, status) },
    swap(alert) {
      swapShifts(alert.member.username, alert.partner.username, alert.index)
      notify(`${alert.member.short} et ${alert.partner.short} ont échangé le ${alert.day}. Échange enregistré localement, sans notification.`)
    },

    cycle(username, index) {
      const current = org.teamPlan.rows[username][index]
      setShift(username, index, CYCLE[(CYCLE.indexOf(current) + 1) % CYCLE.length])
    },

    publish() {
      publishPlan()
      notify(`Planning publié jusqu’au ${dayMonth(this.days[this.days.length - 1])}. Publication enregistrée dans la démonstration, sans notification.`)
    },
  },
}
</script>

<style scoped>
.stack {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.legend {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  font-size: 14.5px;
  color: var(--text-muted);
}
.agent-select { display: none; margin-bottom: 18px; }
.week-tabs button[aria-pressed='true'] { background: var(--brand-soft); border-color: var(--brand); }
.swap-request { padding-top: 14px; margin-top: 14px; border-top: 1px solid var(--border); }
.swap-request p { margin: 8px 0; }
@media (max-width: 760px) { .agent-select { display: flex; } }
</style>
