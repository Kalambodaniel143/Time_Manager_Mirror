<template>
  <div class="payroll">
    <PageHeader :eyebrow="`${monthName} · ${data.rows.length} services`" :title="`Paie de ${monthName}`">
      <button class="btn btn-primary" type="button" @click="exportCsv">
        <AppIcon name="check" />
        Exporter vers la paie
      </button>
    </PageHeader>

    <div class="kpis">
      <article v-for="kpi in kpis" :key="kpi.kind" class="kpi card">
        <HourTag :kind="kpi.kind" />
        <p class="kpi-value serif num">{{ hours(data.totals[kpi.kind]) }}</p>
        <p class="kpi-hint">{{ kpi.hint }}</p>
      </article>
    </div>

    <section class="card services">
      <h2 class="card-title">Par service</h2>
      <div class="table-wrap">
        <table class="table">
          <thead>
            <tr>
              <th scope="col">Service</th>
              <th v-for="column in columns" :key="column.key" scope="col" class="right">{{ column.label }}</th>
              <th scope="col" class="right">Total</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in data.rows" :key="row.service">
              <th scope="row">{{ row.service }}</th>
              <td v-for="column in columns" :key="column.key" class="right num">{{ number(row[column.key]) }}</td>
              <td class="right total serif num">{{ number(row.total) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <InfoNote icon="info" title="Astreintes du Bat-signal" flat>
      Ce sont des horaires contraints prévus au planning : elles ne sont pas comptées comme heures sup.
    </InfoNote>
  </div>
</template>

<script>
import AppIcon from '../components/ui/AppIcon.vue'
import HourTag from '../components/ui/HourTag.vue'
import InfoNote from '../components/ui/InfoNote.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import { org, payroll, payrollCsv } from '../services/orgService'
import { formatHours } from '../utils/hours'
import { notify } from '../utils/toast'

const COLUMNS = [
  { key: 'day', label: 'Jour' },
  { key: 'night', label: 'Nuit ×1,5' },
  { key: 'sup', label: 'Sup. ×2' },
  { key: 'recup', label: 'Récup' },
  { key: 'oncall', label: 'Astreinte' },
  { key: 'leave', label: 'Congé' },
]

export default {
  name: 'PayrollMonth',

  components: { AppIcon, HourTag, InfoNote, PageHeader },

  props: {
    now: { type: Date, required: true },
  },

  data() {
    return { columns: COLUMNS, data: payroll() }
  },

  computed: {
    monthName() {
      const month = new Date(this.now.getFullYear(), this.now.getMonth() - 1, 1)
      return month.toLocaleDateString('fr-FR', { month: 'long' })
    },

    kpis() {
      return [
        { kind: 'day', hint: 'Taux normal' },
        { kind: 'night', hint: 'Payées ×1,5' },
        { kind: 'sup', hint: `Payées ×2, au-delà de ${org.rules.overtimeThreshold} h par semaine` },
        { kind: 'recup', hint: 'Non payées, reprises en repos' },
        { kind: 'oncall', hint: 'Horaires contraints, hors heures sup.' },
        { kind: 'leave', hint: 'Congés et arrêts maladie' },
      ]
    },
  },

  methods: {
    hours(value) {
      return formatHours(value)
    },

    number(value) {
      return value.toLocaleString('fr-FR')
    },

    exportCsv() {
      const blob = new Blob([`﻿${payrollCsv()}`], { type: 'text/csv;charset=utf-8' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `paie-${this.monthName}.csv`
      link.click()
      URL.revokeObjectURL(url)
      notify(`Paie de ${this.monthName} exportée (${this.data.rows.length} services).`)
    },
  },
}
</script>

<style scoped>
.kpis {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 18px;
}

.kpi {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 8px;
  padding: 20px 20px 22px;
}

.kpi-value {
  margin-top: 4px;
  font-size: 46px;
}

.kpi-hint {
  font-size: 14.5px;
  color: var(--text-muted);
}

.services {
  margin: 22px 0;
  padding: 22px 26px 12px;
}

.services .card-title {
  margin-bottom: 14px;
  font-size: 19px;
}

.table-wrap {
  overflow-x: auto;
}

.right {
  text-align: right;
}

.total {
  font-size: 22px;
}

@media (max-width: 1000px) {
  .kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 560px) {
  .kpis {
    grid-template-columns: 1fr;
  }
}
</style>
