<template>
  <div class="hours">
    <PageHeader :eyebrow="`Semaine ${weekNumber} · ${rangeLabel}`" :title="isSelf ? 'Mes heures' : `Heures de l’agent n° ${userID}`">
      <button class="btn btn-outline" type="button" @click="$emit('tour')">
        <AppIcon name="help" />
        Revoir la prise en main
      </button>
    </PageHeader>

    <div class="layout">
      <section class="detail card">
        <header class="detail-header">
          <div class="detail-title">
            <h2 class="card-title">Détail de la semaine</h2>
            <span class="week-nav">
              <button class="btn btn-quiet btn-icon btn-sm" type="button" aria-label="Semaine précédente" @click="shiftWeek(-7)">
                <AppIcon name="chevron-left" />
              </button>
              <button class="btn btn-quiet btn-icon btn-sm" type="button" aria-label="Semaine suivante" :disabled="isCurrentWeek" @click="shiftWeek(7)">
                <AppIcon name="chevron-right" />
              </button>
            </span>
          </div>
          <p class="card-subtitle">
            {{ canEdit ? 'Chaque journée se corrige pendant 7 jours.' : 'Une erreur ? Proposez une correction : votre responsable l’examine avant toute modification.' }}
          </p>
        </header>

        <p v-if="error" class="field-error" role="alert">Impossible de charger vos heures : {{ error }}</p>
        <div v-else-if="loading && workingTimes.length === 0" class="skeleton table-skeleton"></div>
        <!-- Seul l'agent lui-même peut compléter son départ : l'API refuse les autres. -->
        <WeekTable v-else :monday="monday" :entries="workingTimes" :now="now" :user-id="isSelf ? userId : null" :can-edit="canEdit" :can-request="isSelf" @edit="openEdit" @create="openCreate" @completed="onDepartureCompleted" @request="openRequest" />
      </section>

      <aside class="side">
        <LastWeekCard title="Total de la semaine" :buckets="buckets" :target="target" :loading="loading" />
        <ManagerNote v-if="username" :username="username" :week-key="weekKey" />
      </aside>
    </div>
    <CorrectionPanel :user-id="userId" :can-review="!isSelf && canEdit" :refresh-key="correctionVersion" @changed="onDepartureCompleted" />
    <CorrectionRequest v-if="requestEntry" :entry="requestEntry" @close="requestEntry = null" @sent="correctionVersion += 1" />
  </div>
</template>

<script>
import AppIcon from './ui/AppIcon.vue'
import CorrectionRequest from './reviews/CorrectionRequest.vue'
import CorrectionPanel from './reviews/CorrectionPanel.vue'
import PageHeader from './ui/PageHeader.vue'
import LastWeekCard from './employee/LastWeekCard.vue'
import ManagerNote from './hours/ManagerNote.vue'
import WeekTable from './hours/WeekTable.vue'
import { lastWeekMonday, org } from '../services/orgService'
import { getWorkingTimes } from '../services/workingTimeService'
import { canEditHours, isSelf } from '../stores/auth'
import { toDateInput } from '../utils/date'
import { addDays, formatRange, isoWeek, mondayOf, weekBuckets, weekFilters } from '../utils/hours'

export default {
  name: 'WorkingTimes',

  components: { CorrectionRequest, CorrectionPanel, AppIcon, LastWeekCard, ManagerNote, PageHeader, WeekTable },

  props: {
    userID: { type: [Number, String], required: true },
    week: { type: String, default: '' },
    username: { type: String, default: '' },
  },

  emits: ['changed', 'tour'],

  data() {
    return {
      userId: Number(this.userID),
      requestEntry: null,
      correctionVersion: 0,
      workingTimes: [],
      loading: false,
      error: '',
      now: new Date(),
    }
  },

  computed: {
    isSelf() {
      return isSelf(this.userID)
    },

    canEdit() {
      return !this.isSelf && canEditHours(this.userID)
    },

    monday() {
      return this.week ? mondayOf(new Date(`${this.week}T00:00:00`)) : lastWeekMonday()
    },

    filters() {
      return weekFilters(this.monday)
    },

    weekKey() {
      return toDateInput(this.monday)
    },

    weekNumber() {
      return isoWeek(this.monday)
    },

    rangeLabel() {
      return formatRange(this.monday, addDays(this.monday, 6))
    },

    isCurrentWeek() {
      return this.weekKey >= toDateInput(mondayOf(this.now))
    },

    target() {
      return org.rules.overtimeThreshold
    },

    buckets() {
      return weekBuckets(this.workingTimes, this.target)
    },
  },

  watch: {
    userID(value) {
      this.userId = Number(value)
    },

    userId: {
      immediate: true,
      handler() {
        this.getWorkingTimes()
      },
    },

    filters() {
      this.getWorkingTimes()
    },
  },

  mounted() {
    this.minuteTimer = setInterval(() => { this.now = new Date() }, 60000)
  },

  beforeUnmount() {
    clearInterval(this.minuteTimer)
  },

  methods: {
    openRequest(id) { this.requestEntry = this.workingTimes.find(entry => entry.id === id) || null },
    async onDepartureCompleted() {
      await this.getWorkingTimes()
      this.$emit('changed')
    },
    async getWorkingTimes() {
      this.loading = true
      this.error = ''

      try {
        this.workingTimes = (await getWorkingTimes(this.userId, this.filters)) || []
      } catch (error) {
        this.error = error.message
        this.workingTimes = []
      } finally {
        this.loading = false
      }
    },

    shiftWeek(days) {
      this.$router.replace({ query: { ...this.$route.query, semaine: toDateInput(addDays(this.monday, days)) } })
    },

    openEdit(id) {
      this.$router.push({ name: 'workingTimeEdit', params: { userid: this.userId, workingtimeid: id }, query: this.$route.query })
    },

    openCreate() {
      this.$router.push({ name: 'workingTimeCreate', params: { userid: this.userId }, query: this.$route.query })
    },
  },
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 375px;
  gap: 26px;
  align-items: start;
}

.detail {
  padding: 22px 26px 26px;
}

.detail-header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 8px 16px;
  margin-bottom: 14px;
}

.detail-title {
  display: flex;
  align-items: center;
  gap: 10px;
}

.detail-title .card-title {
  font-size: 19px;
}

.week-nav {
  display: inline-flex;
  gap: 2px;
}

.table-skeleton {
  height: 320px;
}

.side {
  display: flex;
  flex-direction: column;
  gap: 22px;
}

@media (max-width: 1180px) {
  .layout {
    grid-template-columns: 1fr;
  }
}
.hours > .corrections { margin-top: 24px; }
</style>
