<template>
  <section class="next-shifts">
    <h2 class="card-title">{{ $t("Prochaines gardes") }}</h2><p v-if="demo" class="field-hint">{{ $t("Exemple de planning · à confirmer auprès de votre responsable.") }}</p>
    <p v-if="loading" role="status">{{ $t("Chargement des gardes…") }}</p>
    <p v-else-if="error" class="field-error" role="alert">{{ $t(error) }}</p>
    <p v-else-if="shifts.length === 0" class="card-subtitle">{{ $t("Aucune garde publiée sur cette période.") }}</p>
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
          <AppIcon name="calendar" /> {{ $t("Publié le") }} {{ $t(demo ? publishedLabel : shift.publishedLabel) }}<template v-if="demo && index === 0">, {{ daysAhead }} {{ $t("jours à l’avance") }}</template>
        </p>
      </div>
    </article>
  </section>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import HourTag from '../ui/HourTag.vue'
import { nextShifts, org, planPublishedOn, isDemoData } from '../../services/orgService'
import { auth } from '../../stores/auth'
import { listPlans } from '../../services/workforceService'
import { clockDate } from '../../utils/missingDeparture'
import { formatClockDate } from '../../utils/clockDate'
import { formatDayMonthLong, weekdayUpper } from '../../utils/hours'

export default {
  name: 'NextShifts',

  components: { AppIcon, HourTag },

  props: {
    today: { type: Date, required: true },
  },

  data() { return { records: [], loading: false, error: '', version: 0 } },
  created() { if (!this.demo) this.load() },
  beforeUnmount() { this.version += 1 },
  computed: {
    demo: isDemoData,
    shifts() {
      if (this.demo) return nextShifts(this.today)
      return this.records.filter(shift => clockDate(shift.start) > this.today).slice(0, 2).map(shift => ({ ...shift, date: clockDate(shift.start), place: shift.place || 'Lieu non renseigné', shift: { from: formatClockDate(shift.start).slice(11,16), to: formatClockDate(shift.end).slice(11,16), hours: (clockDate(shift.end)-clockDate(shift.start))/3600000 }, publishedLabel: shift.published_at.slice(0,10) }))
    },

    publishedLabel() {
      return formatDayMonthLong(planPublishedOn(this.today))
    },

    daysAhead() {
      return org.rules.publishDaysAhead
    },
  },

  methods: {
    async load() { const version = ++this.version; this.loading = true; this.error = ''; try { const plans = await listPlans(); const rows = plans.flatMap(plan => plan.shifts.filter(shift => shift.user_id === auth.user?.id && ['day','night','oncall'].includes(shift.kind)).map(shift => ({ ...shift, published_at: plan.published_at }))).sort((a,b) => a.start.localeCompare(b.start)); if (version === this.version) this.records = rows } catch (error) { if (version === this.version) { this.records = []; this.error = error.message } } finally { if (version === this.version) this.loading = false } },
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
