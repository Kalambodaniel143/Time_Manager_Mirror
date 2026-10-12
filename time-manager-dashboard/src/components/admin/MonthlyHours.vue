<template>
  <div class="monthly-hours">
    <PageHeader :eyebrow="monthLabel" title="Heures du mois">
      <button class="btn btn-outline" type="button" :disabled="loading" @click="load">Actualiser</button>
      <button class="btn btn-primary" type="button" :disabled="loading || !!error || !report.rows.length" @click="download">Télécharger le relevé CSV</button>
    </PageHeader>
    <label class="field month-picker"><span class="field-label">Mois du relevé</span><input v-model="month" class="input" type="month" :max="maxMonth" @change="load" /></label>
    <p class="field-hint">Durées calculées à partir des périodes enregistrées, avec les limites du mois en UTC. Ce relevé ne calcule ni salaire, ni majorations, ni congés et ne transmet rien à un logiciel de paie. Une personne présente dans plusieurs équipes n’est comptée qu’une fois.</p>
    <p v-if="loading" role="status">Chargement des heures…</p>
    <p v-else-if="error" class="field-error" role="alert">Impossible de charger le relevé : {{ error }}</p>
    <section v-else class="card report">
      <h2 class="card-title">{{ hours(report.total) }} enregistrées · {{ report.rows.length }} comptes</h2>
      <p v-if="!report.rows.length" class="muted">Aucun compte accessible.</p>
      <div v-else class="table-scroll"><table class="table"><thead><tr><th scope="col">Agent</th><th scope="col">Équipes</th><th scope="col">Durée</th><th scope="col">Détail</th></tr></thead><tbody><tr v-for="row in report.rows" :key="row.id"><td>{{ row.name }}<p class="field-hint">{{ row.email }}</p></td><td>{{ row.teams || 'Sans équipe' }}</td><td class="num">{{ hours(row.total) }}</td><td><RouterLink class="btn btn-outline btn-sm" :to="{ name: 'workingTimes', params: { userID: row.id } }">Voir les heures</RouterLink></td></tr></tbody></table></div>
    </section>
  </div>
</template>

<script>
import { RouterLink } from 'vue-router'
import PageHeader from '../ui/PageHeader.vue'
import { monthlyReport, reportCsv } from '../../services/reportService'
import { formatHours } from '../../utils/hours'
import { toDateInput } from '../../utils/date'

export default {
  name: 'MonthlyHours',
  components: { PageHeader, RouterLink },
  props: { now: { type: Date, required: true } },
  data() { return { month: toDateInput(new Date(this.now.getFullYear(), this.now.getMonth() - 1, 1)).slice(0, 7), report: { rows: [], total: 0 }, loading: false, error: '', version: 0 } },
  computed: {
    maxMonth() { return toDateInput(this.now).slice(0, 7) },
    monthLabel() { return new Date(`${this.month}-01T00:00:00`).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' }) },
  },
  created() { this.load() },
  beforeUnmount() { this.version += 1 },
  methods: {
    hours: formatHours,
    async load() {
      const version = ++this.version
      this.report = { rows: [], total: 0 }; this.error = ''
      if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(this.month) || this.month > this.maxMonth) { this.error = 'Choisissez un mois valide, sans dépasser le mois actuel.'; this.loading = false; return }
      this.loading = true
      try { const report = await monthlyReport(new Date(`${this.month}-01T00:00:00`)); if (version === this.version) this.report = report }
      catch (error) { if (version === this.version) this.error = error.message }
      finally { if (version === this.version) this.loading = false }
    },
    download() {
      if (this.loading || this.error || !this.report.rows.length) return
      const url = URL.createObjectURL(new Blob([`\uFEFF${reportCsv(this.report)}`], { type: 'text/csv;charset=utf-8' }))
      const link = document.createElement('a'); link.href = url; link.download = `heures-${this.month}.csv`; link.click(); URL.revokeObjectURL(url)
    },
  },
}
</script>

<style scoped>
.monthly-hours { display: flex; flex-direction: column; gap: 20px; }
.month-picker { max-width: 280px; }
.report { padding: 24px; }
.report .card-title { margin-bottom: 18px; }
.table-scroll { overflow-x: auto; }
</style>
