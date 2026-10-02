<template>
  <div class="team-planning">
    <PageHeader :eyebrow="`${published ? 'Publié' : 'À publier'} · ${rangeLabel}`" title="Planning d’équipe">
      <button class="btn btn-primary" type="button" :disabled="!publishable" :title="blockReason" @click="publish">
        <AppIcon name="calendar" />
        {{ published ? `Publié jusqu’au ${endLabel}` : `Publier jusqu’au ${endLabel}` }}
      </button>
    </PageHeader>

    <div class="stack">
      <AlertBanner v-for="alert in alerts" :key="alert.member.username" tone="danger" :title="alert.title" :text="alert.text">
        <button v-if="alert.partner" class="btn btn-on-dark btn-sm" type="button" @click="swap(alert)">
          Échanger le {{ alert.day }} avec {{ alert.partnerFirst }}
        </button>
      </AlertBanner>

      <PlanGrid :days="days" :rows="rows" :max-nights="maxNights" @cycle="cycle" />

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
  org,
  planAlerts,
  publishPlan,
  setShift,
  swapShifts,
  teamPlanDays,
  teamPlanRows,
} from '../services/orgService'
import { formatRange, longestRun } from '../utils/hours'
import { notify } from '../utils/toast'

const CYCLE = ['day', 'night', 'oncall', 'leave', 'rest']

function dayMonth(date) {
  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' })
}

export default {
  name: 'TeamPlanning',

  components: { AlertBanner, AppIcon, HourTag, PageHeader, PlanGrid },

  computed: {
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
      return canPublish('lucie')
    },

    publishable() {
      return !this.published && this.alerts.length === 0 && this.rightGranted
    },

    blockReason() {
      if (this.published) return 'Planning déjà publié.'
      if (this.alerts.length) return 'Corrigez les alertes avant de publier.'
      if (!this.rightGranted) return 'Droit de publication désactivé par l’administration.'
      return ''
    },
  },

  methods: {
    swap(alert) {
      swapShifts(alert.member.username, alert.partner.username, alert.index)
      notify(`${alert.member.short} et ${alert.partner.short} ont échangé le ${alert.day}. Les deux agents seront prévenus.`)
    },

    cycle(username, index) {
      const current = org.teamPlan.rows[username][index]
      setShift(username, index, CYCLE[(CYCLE.indexOf(current) + 1) % CYCLE.length])
    },

    publish() {
      publishPlan()
      notify(`Planning publié jusqu’au ${dayMonth(this.days[this.days.length - 1])}. L’équipe a été prévenue.`)
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
</style>
