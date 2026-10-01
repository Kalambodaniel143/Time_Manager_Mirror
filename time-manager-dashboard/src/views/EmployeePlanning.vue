<template>
  <div class="planning">
    <PageHeader :eyebrow="rangeLabel" title="Mon planning">
      <button class="btn btn-outline" type="button" @click="$emit('tour')">
        <AppIcon name="help" />
        Revoir la prise en main
      </button>
    </PageHeader>

    <div class="layout">
      <div>
        <p class="published">
          <AppIcon name="calendar" />
          Publié le {{ publishedLabel }}, {{ daysAhead }} jours à l’avance. Prochaine publication le {{ nextLabel }}, pour le
          {{ nextRange }}.
        </p>

        <div class="grid">
          <p v-for="label in weekdays" :key="label" class="weekday">{{ label }}</p>
          <article v-for="day in days" :key="day.key" class="day" :class="{ 'is-rest': day.kind === 'rest' }">
            <p class="day-number serif num">{{ day.date.getDate() }}</p>
            <template v-if="day.kind === 'rest'">
              <p class="rest">Repos</p>
            </template>
            <template v-else>
              <HourTag :kind="day.kind" />
              <p class="day-hours num">{{ day.shift.from }} –<br />{{ day.shift.to }}</p>
            </template>
            <p v-if="day.isToday" class="today">Aujourd’hui</p>
          </article>
        </div>

        <p class="legend">
          <HourTag kind="day" />
          <HourTag kind="night" />
          <HourTag kind="oncall" />
          <span>Chaque garde garde sa couleur, du planning à la fiche de paie.</span>
        </p>
      </div>

      <aside class="side">
        <section class="nights card">
          <h2 class="card-title">Mes nuits sur deux semaines</h2>
          <p class="nights-count serif num">{{ nights }} nuit{{ nights > 1 ? 's' : '' }}</p>
          <p class="nights-text">Jamais plus de {{ maxNights }} d’affilée. Chaque nuit est payée ×1,5.</p>
          <HourTag kind="night" :hours="nights * nightHours" />
        </section>

        <button class="btn btn-outline btn-swap" type="button" @click="requestSwap">
          <AppIcon name="users" />
          Demander un échange de garde
        </button>

        <InfoNote icon="calendar" title="Pas de surprise">
          Un changement de dernière minute vous est signalé tout de suite, avec sa raison, et compté dans vos heures.
        </InfoNote>
      </aside>
    </div>
  </div>
</template>

<script>
import AppIcon from '../components/ui/AppIcon.vue'
import HourTag from '../components/ui/HourTag.vue'
import InfoNote from '../components/ui/InfoNote.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import { SHIFT_HOURS, TEAM } from '../mocks/org'
import { employeePlan, org, planPublishedOn, planStart } from '../services/orgService'
import { toDateInput } from '../utils/date'
import { addDays, formatDayMonthLong, formatRange } from '../utils/hours'
import { notify } from '../utils/toast'

const WEEKDAYS = ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.']

export default {
  name: 'EmployeePlanning',

  components: { AppIcon, HourTag, InfoNote, PageHeader },

  props: {
    now: { type: Date, required: true },
  },

  emits: ['tour'],

  data() {
    return { weekdays: WEEKDAYS, nightHours: SHIFT_HOURS.night.hours }
  },

  computed: {
    days() {
      return employeePlan(this.now).map((day) => ({ ...day, key: toDateInput(day.date) }))
    },

    rangeLabel() {
      return formatRange(this.days[0].date, this.days[this.days.length - 1].date)
    },

    publishedLabel() {
      return formatDayMonthLong(planPublishedOn(this.now))
    },

    nextLabel() {
      return formatDayMonthLong(this.days[0].date)
    },

    nextRange() {
      const start = planStart()
      const end = addDays(start, 13)
      return `${start.getDate()} au ${formatDayMonthLong(end)}`
    },

    daysAhead() {
      return org.rules.publishDaysAhead
    },

    maxNights() {
      return org.rules.maxConsecutiveNights
    },

    nights() {
      return this.days.filter((day) => day.kind === 'night').length
    },
  },

  methods: {
    requestSwap() {
      notify(`Demande d’échange envoyée à ${TEAM.manager.short}, votre manager.`)
    },
  },
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 334px;
  gap: 26px;
  align-items: start;
}

.published {
  display: flex;
  gap: 10px;
  margin-bottom: 18px;
  font-size: 14.5px;
  color: var(--text-muted);
}

.published svg {
  width: 18px;
  height: 18px;
  flex-shrink: 0;
}

.grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 10px 9px;
}

.weekday {
  padding-left: 4px;
  font-size: 12.5px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.day {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 10px;
  min-height: 168px;
  padding: 10px 10px 12px;
  background: var(--surface);
  border: var(--card-bw) solid var(--border);
  border-radius: var(--radius-sm);
  box-shadow: var(--shadow-sm);
}

.day.is-rest {
  background: transparent;
  border: 1px dashed var(--rest-bd);
  box-shadow: none;
}

.day-number {
  font-size: 28px;
}

.day :deep(.tag) {
  max-width: calc(100% + 20px);
}

.day-hours {
  font-size: 15px;
  font-weight: 600;
  line-height: 1.4;
}

.rest {
  margin-top: -6px;
  font-size: 14px;
  color: var(--text-muted);
}

.today {
  margin-top: auto;
  font-size: 14.5px;
  font-weight: 700;
  color: var(--title);
}

.legend {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  margin-top: 16px;
  font-size: 14.5px;
  color: var(--text-muted);
}

.side {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.nights {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
  padding: 24px;
}

.nights > .card-title {
  font-size: 19px;
}

.nights-count {
  font-size: 48px;
}

.nights-text {
  font-size: 14.5px;
  color: var(--text-muted);
}

.btn-swap {
  padding: 14px 18px;
  font-size: 16px;
}

@media (max-width: 1180px) {
  .layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 760px) {
  .grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .weekday {
    display: none;
  }

  .day {
    min-height: 0;
  }
}
</style>
