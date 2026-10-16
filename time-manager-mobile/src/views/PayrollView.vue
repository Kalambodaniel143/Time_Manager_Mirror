<template>
  <PageHeader :title="$t('Paie de {0}', [monthLabel(month)])" :eyebrow="`${plural(rows.length, $t('agent'))} · ${plural(services.length, $t('service'))}`">
    <template #action><RefreshButton :busy="loading" @refresh="load" /></template>
  </PageHeader>
  <div class="month-pick">
    <SegmentedTabs v-model="month" :options="months" :label="$t('Mois')" />
    <label class="sr-only" for="month-input">{{ $t('Autre mois') }}</label>
    <input id="month-input" v-model="month" type="month" :max="monthKey(0)" />
  </div>
  <DataState :loading="loading" :error="error" :stale="stale" :updated-at="updatedAt"
    :empty="!rows.length" :empty-text="$t('Aucun agent dans l’organisation.')" @retry="load">
    <section class="card pay-hero">
      <span><span class="kpi-label">{{ $t('Heures travaillées') }}</span><br>
        <span class="small muted">{{ $t('{0} périodes · {1} en moyenne par agent actif', [totals.periods, fmt(average)]) }}</span></span>
      <strong class="kpi-hero-value">{{ fmt(totals.total) }}</strong>
    </section>
    <PayKpis :totals="totals" :labels="labels" :hints="hints" :fmt="fmt" />
    <button type="button" class="btn-outline btn-block" @click="exportCsv">{{ $t('Télécharger le relevé CSV') }}</button>
    <p v-if="exported" class="notice-ok small" role="status">{{ exported }}</p>
    <PayTable :rows="services" :totals="totals" :labels="labels" :num="num" />
    <PayAgents :rows="rows" :labels="labels" :fmt="fmt" />
    <p class="card notice-card small">
      <strong>{{ $t('Astreintes') }}</strong>
      {{ $t('Ce sont des horaires contraints prévus au planning : elles ne sont pas comptées comme heures sup.') }}
      {{ $t('Calcul : périodes découpées en UTC aux limites du mois et de la semaine, heures sup. au-delà de {0} h par semaine, chaque agent compté une fois. Ce relevé n’est pas une fiche de paie.', [threshold]) }}
    </p>
  </DataState>
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import RefreshButton from '@/components/common/RefreshButton.vue'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import DataState from '@/components/common/DataState.vue'
import PayKpis from '@/components/payroll/PayKpis.vue'
import PayTable from '@/components/payroll/PayTable.vue'
import PayAgents from '@/components/payroll/PayAgents.vue'
import loadable from '@/ui/loadable.js'
import { locale, t } from '@/i18n/index.js'
import { app } from '@/services/appState.js'
import { act, api } from '@/services/workforce.js'
import { getMesHeures, getTeams, getUsers } from '@/services/dataService.js'
import { addUp, formatHours, monthSummary, toCsv } from '@/ui/payroll.js'
import { monthKey, monthLabel, monthShort } from '@/ui/weeks.js'
import { displayName, plural } from '@/ui/format.js'

// Paie du mois (comme « Paie » sur le web) : heures par catégorie, par service et par agent,
// calculées à partir des périodes de chacun (GET /users, /teams, /workingtime/:id).
// Règles (seuil, majorations) et absences payées lues sur le serveur quand il les fournit.
export default {
  name: 'PayrollView',
  components: { PageHeader, RefreshButton, SegmentedTabs, DataState, PayKpis, PayTable, PayAgents },
  mixins: [loadable],
  data: () => ({ month: monthKey(-1), people: [], teams: [], rules: {}, absences: [], exported: '' }),
  computed: {
    months: () => [-2, -1, 0].map((o) => ({ value: monthKey(o), label: monthShort(monthKey(o)) })),
    threshold() { return this.rules.overtimeThreshold ?? 40 },
    labels() {
      const x = this.rate
      return { day: t('Jour'), night: t('Nuit ×{0}', [x(this.rules.nightMultiplier ?? 1.5)]), sup: t('Sup. ×{0}', [x(this.rules.overtimeMultiplier ?? 2)]),
        recup: t('Récup'), oncall: t('Astreinte'), leave: t('Congé') }
    },
    hints() {
      return { day: t('Taux normal'), night: t('Payées ×{0}', [this.rate(this.rules.nightMultiplier ?? 1.5)]),
        sup: t('Au-delà de {0} h par semaine', [this.threshold]), recup: t('Non payées, reprises en repos'),
        oncall: t('Horaires contraints, hors heures sup.'), leave: t('Congés et arrêts maladie') }
    },
    // Une ligne par agent (les administrateurs seulement s'ils ont des heures).
    rows() {
      return this.people.map(({ user, periods }) => {
        const team = this.teams.find((tm) => tm.members.some((m) => m.id === user.id)) ?? this.teams.find((tm) => tm.manager?.id === user.id)
        const absences = this.absences.filter((a) => a.user_id === user.id)
        return { id: user.id, name: displayName(user), email: user.email, team: team?.name ?? t('Sans équipe'),
          ...monthSummary(periods, this.month, { threshold: this.threshold, absences }) }
      }).filter((r) => this.people.find((p) => p.user.id === r.id).user.role !== 'administrator' || r.total)
        .sort((a, b) => b.total - a.total || a.name.localeCompare(b.name))
    },
    services() {
      const names = [...new Set(this.rows.map((r) => r.team))]
      return names.map((name) => {
        const list = this.rows.filter((r) => r.team === name)
        return { name, count: list.length, ...addUp(list) }
      }).sort((a, b) => b.total - a.total)
    },
    totals() { return addUp(this.rows) },
    average() {
      const active = this.rows.filter((r) => r.total).length
      return active ? this.totals.total / active : 0
    },
  },
  created() { this.load() },
  methods: {
    monthKey, monthLabel, plural,
    rate: (n) => Number(n).toLocaleString(locale()),
    fmt: (value) => formatHours(value ?? 0, locale()),
    num: (value) => Number(value ?? 0).toLocaleString(locale(), { maximumFractionDigits: 1 }),
    // Les heures ne dépendent pas du mois affiché : changer de mois ne recharge rien.
    async load() {
      this.people = (await this.run(async () => {
        const [users, teams] = await Promise.all([getUsers(), getTeams().catch(() => ({ data: [] }))])
        this.teams = teams.data ?? []
        const people = await Promise.all(users.data.map(async (user) => ({ user, periods: (await getMesHeures(user.id).catch(() => null))?.data ?? [] })))
        return { data: people, stale: users.stale, updatedAt: users.updatedAt }
      })) ?? []
      // Facultatif : règles et absences, si le serveur a ces routes.
      if (app.organization) act(() => api.getRules(app.organization.id)).then((r) => { this.rules = r?.rules ?? r ?? {} }).catch(() => {})
      act(() => api.getAbsences()).then((list) => { this.absences = list ?? [] }).catch(() => {})
    },
    // Navigateur : téléchargement. Téléphone : copie dans le presse-papiers, à coller dans un tableur.
    async exportCsv() {
      const csv = toCsv(this.rows, this.labels)
      if (!window.cordova) {
        const link = Object.assign(document.createElement('a'), { href: URL.createObjectURL(new Blob([`﻿${csv}`], { type: 'text/csv;charset=utf-8' })), download: `paie-${this.month}.csv` })
        link.click()
        URL.revokeObjectURL(link.href)
        this.exported = t('Relevé de {0} téléchargé ({1} agents).', [monthLabel(this.month), this.rows.length])
        return
      }
      try { await navigator.clipboard.writeText(csv); this.exported = t('Relevé copié : collez-le dans un tableur.') } catch { this.exported = t('Copie impossible sur ce téléphone.') }
    },
  },
}
</script>
