<template>
  <div class="monthly-hours">
    <PageHeader :eyebrow="$t(monthLabel)" :title="$t(&quot;Paie et heures du mois&quot;)">
      <button class="btn btn-outline" type="button" :disabled="loading" @click="load">{{ $t("Actualiser") }}</button>
      <button class="btn btn-primary" type="button" :disabled="loading || !!error || !report.rows.length" @click="download">{{ $t("Télécharger le relevé CSV") }}</button>
    </PageHeader>
    <label class="field month-picker"><span class="field-label">{{ $t("Mois du relevé") }}</span><input v-model="month" class="input" type="month" :max="maxMonth" @change="load" /></label>
    <p class="field-hint">{{ $t("Durées calculées à partir des périodes enregistrées, avec les limites du mois en UTC. Le serveur distingue jour, nuit, heures supplémentaires, récupération et absences. Le montant utilise le taux horaire renseigné et les catégories d’absence que l’administration a choisi de rémunérer. Les heures rémunérables d’absence sont confirmées par le responsable ; un montant reste indisponible si cette confirmation manque. Les semaines non validées restent signalées. Une personne présente dans plusieurs équipes n’est comptée qu’une fois.") }}</p>
    <p v-if="loading" role="status">{{ $t("Chargement des heures…") }}</p>
    <p v-else-if="error" class="field-error" role="alert">{{ $t("Impossible de charger le relevé :") }} {{ $t(error) }}</p>
    <section v-else class="card report">
      <h2 class="card-title">{{ hours(report.total) }} {{ $t("enregistrées ·") }} {{ report.rows.length }} {{ $t("comptes") }}</h2>
      <p v-if="!report.rows.length" class="muted">{{ $t("Aucun compte accessible.") }}</p>
      <div v-else class="table-scroll"><table class="table"><thead><tr><th scope="col">{{ $t("Agent") }}</th><th v-for="column in columns" :key="column.key" scope="col">{{ $t(column.label) }}</th><th scope="col">{{ $t("Montant calculé") }}</th><th scope="col">{{ $t("État") }}</th><th scope="col">{{ $t("Durée") }}</th><th scope="col">{{ $t("Détail") }}</th></tr></thead><tbody><tr v-for="row in report.rows" :key="row.id"><td>{{ row.name }}<p class="field-hint">{{ row.email }}</p></td><td v-for="column in columns" :key="column.key" class="num">{{ hours(row[column.key]) }}</td><td>{{ $t(row.amount === null ? (row.absence_payment_incomplete ? 'Heures d’absence à confirmer' : 'Taux non renseigné') : `${row.amount} ${row.currency}`) }}<button class="btn btn-quiet btn-sm" @click="openRate(row)">{{ $t("Modifier le taux") }}</button></td><td>{{ $t(row.absence_conflict ? 'Travail pendant une absence : à régulariser' : row.confirmed ? 'Semaines validées' : 'À vérifier') }}</td><td class="num">{{ hours(row.total) }}</td><td><RouterLink class="btn btn-outline btn-sm" :to="{ name: 'workingTimes', params: { userID: row.id } }">{{ $t("Voir les heures") }}</RouterLink></td></tr></tbody></table></div>
    </section>
    <ModalDialog v-if="rateTarget" :title="$t(&quot;Taux horaire de l’agent&quot;)" id="payroll-rate" :busy="busy" @close="rateTarget = null"><p>{{ rateTarget.name }}</p><label class="field"><span class="field-label">{{ $t("Taux horaire") }}</span><input v-model="rate" class="input" type="number" min="0" max="100000" step="0.01" /></label><label class="field"><span class="field-label">{{ $t("Devise") }}</span><select v-model="currency" class="input"><option>{{ $t("EUR") }}</option><option>{{ $t("USD") }}</option><option>{{ $t("GBP") }}</option></select></label><p v-if="rateError" class="field-error" role="alert">{{ $t(rateError) }}</p><button class="btn btn-primary" :disabled="busy" @click="saveRate">{{ $t("Enregistrer") }}</button></ModalDialog>
  </div>
</template>

<script>
import { intlLocale } from '../../utils/i18n.js'

import { RouterLink } from 'vue-router'
import PageHeader from '../ui/PageHeader.vue'
import { getPayroll, exportPayroll, savePayProfile } from '../../services/workforceService'
import ModalDialog from '../ui/ModalDialog.vue'
import { formatHours } from '../../utils/hours'
import { toDateInput } from '../../utils/date'

export default {
  name: 'MonthlyHours',
  components: { ModalDialog, PageHeader, RouterLink },
  props: { now: { type: Date, required: true } },
  data() { return { month: toDateInput(new Date(this.now.getFullYear(), this.now.getMonth() - 1, 1)).slice(0, 7), report: { rows: [], total: 0 }, loading: false, error: '', version: 0, rateTarget: null, rate: '', currency: 'EUR', rateError: '', busy: false, columns: [{key:'day',label:'Jour'}, {key:'night',label:'Nuit ×1,5'}, {key:'sup',label:'Sup. ×2'}, {key:'recup',label:'Récupération'}, {key:'oncall',label:'Astreinte'}, {key:'leave',label:'Congé'}, {key:'sick',label:'Maladie'}, {key:'recup_taken',label:'Récupération prise'}, {key:'paid_absence_hours',label:'Absence rémunérée'}] } },
  computed: {
    maxMonth() { return toDateInput(this.now).slice(0, 7) },
    monthLabel() { return new Date(`${this.month}-01T00:00:00`).toLocaleDateString(intlLocale(), { month: 'long', year: 'numeric' }) },
  },
  created() { this.load() },
  beforeUnmount() { this.version += 1 },
  methods: {
    hours: formatHours,
    openRate(row) { this.rateTarget = row; this.rate = row.hourly_rate || ''; this.currency = row.currency; this.rateError = '' },
    async saveRate() { if (this.busy) return; this.busy = true; this.rateError = ''; try { await savePayProfile(this.rateTarget.id, { hourly_rate: this.rate === '' ? null : this.rate, currency: this.currency }); this.rateTarget = null; await this.load() } catch (error) { this.rateError = error.message } finally { this.busy = false } },
    async load() {
      const version = ++this.version
      this.report = { rows: [], total: 0 }; this.error = ''
      if (!/^\d{4}-(0[1-9]|1[0-2])$/.test(this.month) || this.month > this.maxMonth) { this.error = 'Choisissez un mois valide, sans dépasser le mois actuel.'; this.loading = false; return }
      this.loading = true
      try { const report = await getPayroll(this.month); if (version === this.version) { this.report = report; this.columns.find(column => column.key === 'night').label = `Nuit ×${report.rules.nightMultiplier}`; this.columns.find(column => column.key === 'sup').label = `Sup. ×${report.rules.overtimeMultiplier}` } }
      catch (error) { if (version === this.version) this.error = error.message }
      finally { if (version === this.version) this.loading = false }
    },
    async download() {
      if (this.loading || this.error || !this.report.rows.length) return
      let csv
      try { csv = await exportPayroll(this.month) } catch (error) { this.error = error.message; return }
      const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }))
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
