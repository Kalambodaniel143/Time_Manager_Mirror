<template>
  <div class="today">
    <PageHeader :eyebrow="dateLabel" :title="`${greetingText} ${firstName}`"><button class="btn btn-outline btn-sm" type="button" @click="$emit('tour')"><AppIcon name="help" />Revoir la prise en main</button></PageHeader>
    <MissingDeparture v-if="userId" ref="missingDeparture" :user-id="userId" :now="now" @completed="onDepartureCompleted" @refreshed="onDepartureCompleted" />
    <div class="layout">
      <div class="column"><ClockManager v-if="userId" ref="clockManager" :user-id="userId" @changed="onClockChanged" /><p v-else class="card clock-waiting" role="status">Le pointage sera disponible une fois votre profil chargé.</p><InfoNote title="Vos heures vous appartiennent" flat>Un oubli ? Complétez votre départ. Une erreur dans vos heures ? Proposez une correction : votre responsable l’examine avant modification.</InfoNote></div>
      <div class="column"><LastWeekCard :title="`Semaine dernière · ${lastWeekRange}`" :buckets="buckets" :target="target" :loading="loading" /><NextShifts :today="now" /></div>
      <TransparencyPanel />
    </div>
  </div>
</template>

<script>
import ClockManager from '../components/ClockManager.vue'
import AppIcon from '../components/ui/AppIcon.vue'
import InfoNote from '../components/ui/InfoNote.vue'
import MissingDeparture from '../components/MissingDeparture.vue'
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

  components: { AppIcon, ClockManager, InfoNote, MissingDeparture, LastWeekCard, NextShifts, PageHeader, TransparencyPanel },

  props: {
    persona: { type: Object, required: true },
    userId: { type: [Number, String], default: null },
    workingTimes: { type: Array, default: () => [] },
    loading: { type: Boolean, default: false },
    now: { type: Date, required: true },
  },

  // Relayer le pointage à App.vue pour recharger les heures enregistrées.
  emits: ['tour', 'changed'],

  methods: {
    onClockChanged() {
      this.$refs.missingDeparture?.refresh()
      this.$emit('changed')
    },
    onDepartureCompleted() {
      this.$refs.clockManager?.refresh()
      this.$emit('changed')
    },
  },

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
  grid-template-columns: minmax(230px, 1fr) minmax(260px, 1.1fr) minmax(220px, .9fr);
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

.clock-panel {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.clock-waiting {
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
.today > section { margin-bottom: 20px; }
@media (max-width: 1180px) { .layout { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); } .layout > .transparency { grid-column: 1 / -1; } }
@media (max-width: 760px) { .layout { grid-template-columns: 1fr; } .layout > .transparency { grid-column: auto; } }
</style>
