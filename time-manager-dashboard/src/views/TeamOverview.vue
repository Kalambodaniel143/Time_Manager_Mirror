<template>
  <div class="team">
    <PageHeader :eyebrow="`Semaine ${weekNumber} · ${rangeLabel}`" :title="teamName">
      <button class="btn btn-primary" type="button" :disabled="selection.length === 0" @click="validate">
        <AppIcon name="check" />
        Valider {{ selection.length }} feuille{{ selection.length > 1 ? 's' : '' }}
      </button>
    </PageHeader>

    <div class="stack">
      <AlertBanner
        v-for="alert in nightAlerts"
        :key="alert.username"
        tone="danger"
        :title="`${alert.short} a fait ${alert.nightRun} nuits d’affilée la semaine dernière`"
        :text="alert.text"
      >
        <RouterLink class="btn btn-on-dark btn-sm" :to="{ name: 'teamPlanning' }">Voir le planning à venir</RouterLink>
      </AlertBanner>

      <JonasMarker title="Alerte « Sara O. n’a pas pointé son départ vendredi »" inline>
        Bandeau jaune + « Demander l’heure à Sara », calculé depuis les pointages.
      </JonasMarker>

      <section class="card list">
        <header class="list-header">
          <label class="select-all">
            <input type="checkbox" class="check" :checked="allClean" :disabled="cleanRows.length === 0" @change="toggleAll" />
            Tout sélectionner sans anomalie ({{ cleanRows.length }})
          </label>
          <p class="list-hint">Anomalies en premier · notes des agents visibles sans clic</p>
        </header>

        <div v-if="loading" class="skeleton list-skeleton"></div>
        <p v-else-if="error" class="field-error list-error" role="alert">Impossible de charger l’équipe : {{ error }}</p>
        <ul v-else class="rows">
          <TeamMemberRow
            v-for="row in sortedRows"
            :key="row.username"
            :row="row"
            :selected="selection.includes(row.username)"
            :max-nights="maxNights"
            @toggle="toggle"
          />
        </ul>
      </section>
    </div>
  </div>
</template>

<script>
import { RouterLink } from 'vue-router'
import AlertBanner from '../components/ui/AlertBanner.vue'
import AppIcon from '../components/ui/AppIcon.vue'
import JonasMarker from '../components/ui/JonasMarker.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import TeamMemberRow from '../components/manager/TeamMemberRow.vue'
import { isValidated, lastWeekMonday, noteFor, org, planAlerts, team, validateSheets } from '../services/orgService'
import { listUsers } from '../services/userService'
import { getWorkingTimes } from '../services/workingTimeService'
import { toDateInput } from '../utils/date'
import { addDays, formatRange, isoWeek, weekBuckets, weekFilters, weekNightRun } from '../utils/hours'
import { notify } from '../utils/toast'

export default {
  name: 'TeamOverview',

  components: { AlertBanner, AppIcon, JonasMarker, PageHeader, RouterLink, TeamMemberRow },

  data() {
    return {
      monday: lastWeekMonday(),
      teamName: team().name,
      entries: {},
      selection: [],
      loading: false,
      error: '',
    }
  },

  computed: {
    weekKey() {
      return toDateInput(this.monday)
    },

    weekNumber() {
      return isoWeek(this.monday)
    },

    rangeLabel() {
      return formatRange(this.monday, addDays(this.monday, 6))
    },

    maxNights() {
      return org.rules.maxConsecutiveNights
    },

    rows() {
      return team().members.map((member) => {
        const entries = this.entries[member.username] || []
        return {
          ...member,
          buckets: weekBuckets(entries, org.rules.overtimeThreshold),
          nightRun: weekNightRun(entries, this.monday),
          note: noteFor(member.username, this.weekKey),
          validated: isValidated(member.username, this.weekKey),
        }
      })
    },

    sortedRows() {
      return [...this.rows].sort((a, b) => Number(this.hasAnomaly(b)) - Number(this.hasAnomaly(a)))
    },

    cleanRows() {
      return this.rows.filter((row) => !this.hasAnomaly(row) && !row.validated)
    },

    allClean() {
      return this.cleanRows.length > 0 && this.cleanRows.every((row) => this.selection.includes(row.username))
    },

    nightAlerts() {
      const upcoming = planAlerts()
      return this.rows
        .filter((row) => row.nightRun > this.maxNights)
        .map((row) => {
          const planned = upcoming.find((alert) => alert.member.username === row.username)
          const next = planned
            ? `Le planning à venir en prévoit encore ${planned.run.length} : ajustez-le avant de le publier.`
            : 'Le planning à venir respecte le seuil.'
          return { ...row, text: `Le seuil de l’équipe est de ${this.maxNights}. ${next}` }
        })
    },
  },

  created() {
    this.loadTeam()
  },

  methods: {
    hasAnomaly(row) {
      return row.nightRun > this.maxNights
    },

    async loadTeam() {
      this.loading = true
      this.error = ''

      try {
        const users = (await listUsers()) || []
        const pairs = await Promise.all(
          team().members.map(async (member) => {
            const user = users.find((item) => item.username === member.username)
            const entries = user ? (await getWorkingTimes(user.id, weekFilters(this.monday))) || [] : []
            return [member.username, entries]
          }),
        )
        this.entries = Object.fromEntries(pairs)
        this.selection = this.cleanRows.map((row) => row.username)
      } catch (error) {
        this.error = error.message
      } finally {
        this.loading = false
      }
    },

    toggle(username) {
      this.selection = this.selection.includes(username)
        ? this.selection.filter((item) => item !== username)
        : [...this.selection, username]
    },

    toggleAll() {
      const clean = this.cleanRows.map((row) => row.username)
      this.selection = this.allClean
        ? this.selection.filter((item) => !clean.includes(item))
        : [...new Set([...this.selection, ...clean])]
    },

    validate() {
      const count = this.selection.length
      validateSheets(this.selection, this.weekKey)
      this.selection = []
      notify(`${count} feuille${count > 1 ? 's' : ''} validée${count > 1 ? 's' : ''}. Les agents ont été prévenus.`)
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

.list {
  overflow: hidden;
}

.list-header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 8px 16px;
  padding: 14px 18px;
}

.select-all {
  display: flex;
  align-items: center;
  gap: 14px;
  font-size: 16px;
  font-weight: 700;
}

.check {
  width: 22px;
  height: 22px;
  accent-color: var(--brand);
}

.list-hint {
  font-size: 14px;
  color: var(--text-muted);
}

.rows {
  margin: 0;
  padding: 0;
  list-style: none;
}

.list-skeleton {
  height: 360px;
  margin: 0 18px 18px;
}

.list-error {
  padding: 0 18px 18px;
}
</style>
