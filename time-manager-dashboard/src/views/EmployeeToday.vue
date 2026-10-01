<template>
  <div class="today">
    <PageHeader :eyebrow="dateLabel" :title="`${greetingText} ${firstName}`">
      <button class="btn btn-outline" type="button" @click="$emit('tour')">
        <AppIcon name="help" />
        Revoir la prise en main
      </button>
    </PageHeader>

    <div class="layout">
      <div class="column">
        <section class="clock card">
          <JonasMarker title="Grand rond de pointage">
            « Pointer mon arrivée / mon départ », heure d’arrivée pointée et durée en cours, bouton « Prendre une pause ».
            <RouterLink v-if="userId" class="link" :to="{ name: 'clock', params: { userid: userId } }">Pointage actuel</RouterLink>
          </JonasMarker>
          <p class="clock-privacy">
            <AppIcon name="shield" />
            Seules vos heures d’arrivée et de départ sont enregistrées.
          </p>
        </section>

        <InfoNote title="Vos heures vous appartiennent">
          Vous voyez tout ce que voit votre manager, et vous pouvez corriger une journée pendant 7 jours.
        </InfoNote>
      </div>

      <div class="column">
        <JonasMarker title="Alerte « Votre départ de vendredi n’est pas pointé »" inline>
          Bandeau jaune + bouton « Compléter », calculé depuis les pointages.
        </JonasMarker>

        <LastWeekCard :title="`Semaine dernière · ${lastWeekRange}`" :buckets="buckets" :target="target" :loading="loading" />

        <div class="split">
          <NextShifts :today="now" />
          <TransparencyPanel />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { RouterLink } from 'vue-router'
import AppIcon from '../components/ui/AppIcon.vue'
import InfoNote from '../components/ui/InfoNote.vue'
import JonasMarker from '../components/ui/JonasMarker.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import LastWeekCard from '../components/employee/LastWeekCard.vue'
import NextShifts from '../components/employee/NextShifts.vue'
import TransparencyPanel from '../components/employee/TransparencyPanel.vue'
import { lastWeekMonday, org } from '../services/orgService'
import { toDateInput } from '../utils/date'
import { addDays, formatRange, weekBuckets } from '../utils/hours'
import { greeting } from '../utils/people'

export default {
  name: 'EmployeeToday',

  components: { AppIcon, InfoNote, JonasMarker, LastWeekCard, NextShifts, PageHeader, RouterLink, TransparencyPanel },

  props: {
    persona: { type: Object, required: true },
    userId: { type: [Number, String], default: null },
    workingTimes: { type: Array, default: () => [] },
    loading: { type: Boolean, default: false },
    now: { type: Date, required: true },
  },

  emits: ['tour'],

  computed: {
    dateLabel() {
      return this.now.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })
    },

    greetingText() {
      return greeting(this.now)
    },

    firstName() {
      return this.persona.name.split(' ')[0]
    },

    monday() {
      return lastWeekMonday()
    },

    lastWeekRange() {
      return formatRange(this.monday, addDays(this.monday, 6))
    },

    target() {
      return org.rules.overtimeThreshold
    },

    buckets() {
      const from = toDateInput(this.monday)
      const to = toDateInput(addDays(this.monday, 7))
      const entries = this.workingTimes.filter((entry) => entry.start.slice(0, 10) >= from && entry.start.slice(0, 10) < to)
      return weekBuckets(entries, this.target)
    },
  },
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: minmax(0, 375px) minmax(0, 1fr);
  gap: 26px;
  align-items: start;
}

.column {
  display: flex;
  flex-direction: column;
  gap: 26px;
}

.split {
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
  gap: 26px;
  align-items: start;
}

.clock {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 24px;
}

.clock-privacy {
  display: flex;
  gap: 10px;
  font-size: 14px;
  color: var(--text-muted);
}

.clock-privacy svg {
  width: 16px;
  height: 16px;
  margin-top: 2px;
}

@media (max-width: 1180px) {
  .split {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 900px) {
  .layout {
    grid-template-columns: 1fr;
  }
}
</style>
