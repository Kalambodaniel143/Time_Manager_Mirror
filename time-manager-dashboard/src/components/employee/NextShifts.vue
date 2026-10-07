<template>
  <section class="next-shifts">
    <h2 class="card-title">Prochaines gardes</h2><p class="field-hint">Exemple de planning · à confirmer auprès de votre responsable.</p>
    <p v-if="shifts.length === 0" class="card-subtitle">Aucune garde de nuit ou d’astreinte prévue.</p>
    <article v-for="(shift, index) in shifts" :key="shift.date.toISOString()" class="shift card">
      <div class="shift-date">
        <span class="shift-weekday">{{ weekday(shift.date) }}</span>
        <span class="shift-day serif num">{{ shift.date.getDate() }}</span>
      </div>
      <div class="shift-body">
        <p class="shift-hours num">{{ shift.shift.from }} – {{ shift.shift.to }}</p>
        <p class="shift-place">{{ shift.place }}</p>
        <HourTag :kind="shift.kind" :hours="shift.shift.hours" />
        <p class="shift-published">
          <AppIcon name="calendar" />
          Publié le {{ publishedLabel }}<template v-if="index === 0">, {{ daysAhead }} jours à l’avance</template>
        </p>
      </div>
    </article>
  </section>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import HourTag from '../ui/HourTag.vue'
import { nextShifts, org, planPublishedOn } from '../../services/orgService'
import { formatDayMonthLong, weekdayUpper } from '../../utils/hours'

export default {
  name: 'NextShifts',

  components: { AppIcon, HourTag },

  props: {
    today: { type: Date, required: true },
  },

  computed: {
    shifts() {
      return nextShifts(this.today)
    },

    publishedLabel() {
      return formatDayMonthLong(planPublishedOn(this.today))
    },

    daysAhead() {
      return org.rules.publishDaysAhead
    },
  },

  methods: {
    weekday(date) {
      return `${weekdayUpper(date).replace('.', '')}.`
    },
  },
}
</script>

<style scoped>
.next-shifts {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.next-shifts > .card-title {
  font-size: 19px;
}

.shift {
  display: flex;
  gap: 18px;
  padding: 16px;
}

.shift-date {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 66px;
  min-height: 136px;
  background: var(--night-bg);
  color: var(--night-fg);
}

.shift-weekday {
  font-size: 14px;
  font-weight: 700;
}

.shift-day {
  font-size: 34px;
}

.shift-body {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 6px;
}

.shift-hours {
  font-size: 20px;
  font-weight: 700;
}

.shift-place {
  font-size: 14px;
  color: var(--text-muted);
}

.shift-published {
  display: flex;
  gap: 8px;
  margin-top: 4px;
  font-size: 14px;
  color: var(--text-muted);
}

.shift-published svg {
  width: 16px;
  height: 16px;
  margin-top: 2px;
}
.shift { gap: 12px; padding: 14px; }
.shift-date { width: 48px; min-height: 75px; border-radius: 6px; background: var(--brand); color: var(--on-brand); }
.shift-day { font-size: 25px; }
.shift-weekday { font-size: 11px; }
</style>
