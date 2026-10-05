<template>
  <div class="team">
    <PageHeader :eyebrow="`Semaine ${weekNumber} · ${rangeLabel}`" :title="teamName">
      <button class="btn btn-outline" type="button" :disabled="loading" @click="loadTeam">
        {{ loading ? 'Actualisation…' : 'Actualiser' }}
      </button>
      <button class="btn btn-primary" type="button" :disabled="loading || !!error || selection.length === 0" @click="validate">
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

      <!-- Les alertes viennent des pointages de l'API, pour chaque membre connu. -->
      <template v-if="!loading && !error">
        <AlertBanner
          v-for="row in departureAlerts"
          :key="`departure-${row.username}`"
          class="departure-alert"
          :title="`${row.short} : départ à vérifier`"
          :text="`Service commencé le ${arrivalLabel(row)}. Aucun départ enregistré depuis plus de 24 heures.`"
        >
          <a v-if="departureMail(row)" class="btn btn-outline btn-sm" :href="departureMail(row)">
            Demander l’heure à {{ row.name.split(' ')[0] }}
          </a>
          <span v-else class="mail-hint">Adresse e-mail indisponible : contactez directement ce salarié.</span>
        </AlertBanner>
        <p v-if="departureAlerts.length" class="mail-hint">
          « Demander l’heure » prépare un e-mail dans votre messagerie. Vous choisissez de l’envoyer.
          Après la correction du salarié, cliquez sur « Actualiser ».
        </p>
        <AlertBanner v-if="clockProblems.length" title="Pointages non vérifiés" :text="clockProblems.join(' · ')" />
      </template>

      <section class="card list">
        <header class="list-header">
          <label class="select-all">
            <input type="checkbox" class="check" :checked="allClean" :disabled="loading || !!error || cleanRows.length === 0" @change="toggleAll" />
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
import PageHeader from '../components/ui/PageHeader.vue'
import TeamMemberRow from '../components/manager/TeamMemberRow.vue'
import { isValidated, lastWeekMonday, noteFor, org, planAlerts, team, validateSheets } from '../services/orgService'
import { listUsers } from '../services/userService'
import { getWorkingTimes } from '../services/workingTimeService'
import { getClocks } from '../services/clockService'
import { clockDate, findMissingDeparture } from '../utils/missingDeparture'
import { formatClockDate } from '../utils/clockDate'
import { toDateInput } from '../utils/date'
import { addDays, formatRange, isoWeek, weekBuckets, weekFilters, weekNightRun } from '../utils/hours'
import { notify } from '../utils/toast'

export default {
  name: 'TeamOverview',

  components: { AlertBanner, AppIcon, PageHeader, RouterLink, TeamMemberRow },

  props: {
    now: { type: Date, default: () => new Date() },
  },

  data() {
    return {
      monday: lastWeekMonday(),
      teamName: team().name,
      entries: {},
      users: {},
      clocks: {},
      clockErrors: {},
      selection: [],
      loading: false,
      error: '',
      requestVersion: 0,
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
        const missingDeparture = findMissingDeparture(this.clocks[member.username] || [], this.now)
        const day = missingDeparture ? formatClockDate(missingDeparture.arrival.time).slice(0, 10) : ''
        return {
          ...member,
          user: this.users[member.username],
          missingDeparture,
          // La validation concerne la semaine affichée, pas un service d'une autre semaine.
          departureInWeek: !!missingDeparture && day >= this.weekKey && day < toDateInput(addDays(this.monday, 7)),
          clockError: this.clockErrors[member.username] || '',
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

    departureAlerts() {
      return this.rows.filter((row) => row.missingDeparture)
    },

    clockProblems() {
      return this.rows.filter((row) => row.clockError).map((row) => `${row.short} : ${row.clockError}`)
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

  watch: {
    // Le seuil de 24 h peut être franchi pendant que la page reste ouverte.
    rows() {
      this.selection = this.selection.filter((username) => this.rows.some((row) => row.username === username && this.canSelect(row)))
    },
  },

  beforeUnmount() {
    this.requestVersion += 1
  },

  methods: {
    hasAnomaly(row) {
      return row.nightRun > this.maxNights || row.departureInWeek || !!row.clockError
    },

    canSelect(row) {
      return !row.validated && !row.departureInWeek && !row.clockError
    },

    arrivalLabel(row) {
      return clockDate(row.missingDeparture.arrival.time).toLocaleString('fr-FR', { dateStyle: 'full', timeStyle: 'long' })
    },

    departureMail(row) {
      const email = typeof row.user?.email === 'string' ? row.user.email.trim() : ''
      if (!email || !/^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$/.test(email)) return ''
      const subject = 'Time Manager — heure de départ à compléter'
      const body = `Bonjour ${row.name},\n\nAucun départ n’est enregistré pour ton service commencé le ${this.arrivalLabel(row)}.\nPeux-tu confirmer la date et l’heure réelles de ton départ ? Si ce départ date de moins de 7 jours, tu peux le compléter dans « Aujourd’hui » ou « Mes heures ».\n\nMerci.`
      return `mailto:${encodeURIComponent(email)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`
    },

    async loadTeam() {
      if (this.loading) return
      const version = ++this.requestVersion
      this.loading = true
      this.error = ''
      this.selection = []

      try {
        const users = await listUsers()
        if (!Array.isArray(users)) throw new Error('Liste des utilisateurs invalide')
        const records = await Promise.all(
          team().members.map(async (member) => {
            const user = users.find((item) => item && item.username === member.username)
            if (!user) return { username: member.username, entries: [], clocks: [], clockError: 'profil absent de l’API' }

            // Un échec de lecture des pointages ne masque pas les alertes des autres membres.
            const readClocks = getClocks(user.id).then((clocks) => {
              if (!Array.isArray(clocks)) throw new Error('Pointages invalides')
              findMissingDeparture(clocks, this.now)
              return { clocks, clockError: '' }
            }).catch(() => ({ clocks: [], clockError: 'pointages indisponibles, actualisez pour réessayer' }))
            const [entries, clockResult] = await Promise.all([getWorkingTimes(user.id, weekFilters(this.monday)), readClocks])
            if (!Array.isArray(entries)) throw new Error('Liste des heures invalide')
            return { username: member.username, user, entries, ...clockResult }
          }),
        )
        if (version !== this.requestVersion) return
        this.entries = Object.fromEntries(records.map((record) => [record.username, record.entries]))
        this.clocks = Object.fromEntries(records.map((record) => [record.username, record.clocks]))
        this.clockErrors = Object.fromEntries(records.map((record) => [record.username, record.clockError]))
        this.users = Object.fromEntries(records.map((record) => [record.username, record.user]))
        this.selection = this.cleanRows.map((row) => row.username)
      } catch (error) {
        if (version !== this.requestVersion) return
        this.error = error.message
      } finally {
        if (version === this.requestVersion) this.loading = false
      }
    },

    toggle(username) {
      const row = this.rows.find((item) => item.username === username)
      if (this.loading || this.error || !row || !this.canSelect(row)) return
      this.selection = this.selection.includes(username)
        ? this.selection.filter((item) => item !== username)
        : [...this.selection, username]
    },

    toggleAll() {
      if (this.loading || this.error) return
      const clean = this.cleanRows.map((row) => row.username)
      this.selection = this.allClean
        ? this.selection.filter((item) => !clean.includes(item))
        : [...new Set([...this.selection, ...clean])]
    },

    validate() {
      if (this.loading || this.error) return
      const selected = this.selection.filter((username) => this.rows.some((row) => row.username === username && this.canSelect(row)))
      const count = selected.length
      if (count === 0) return
      validateSheets(selected, this.weekKey)
      this.selection = []
      notify(`${count} feuille${count > 1 ? 's' : ''} validée${count > 1 ? 's' : ''}.`)
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

.mail-hint {
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

@media (max-width: 600px) {
  .departure-alert {
    display: grid;
    grid-template-columns: 22px minmax(0, 1fr);
    align-items: start;
  }

  .departure-alert .btn,
  .departure-alert .mail-hint {
    grid-column: 2;
    justify-self: start;
    max-width: 100%;
    white-space: normal;
  }
}
</style>
