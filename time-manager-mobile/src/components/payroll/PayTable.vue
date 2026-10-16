<template>
  <section class="card">
    <h2>{{ $t('Par service') }}</h2>
    <div class="table-wrap">
      <table class="data-table pay-table small">
        <thead>
          <tr>
            <th scope="col">{{ $t('Service') }}</th>
            <th v-for="c in CATEGORIES" :key="c" scope="col">{{ labels[c] }}</th>
            <th scope="col">{{ $t('Total') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in rows" :key="row.name">
            <th scope="row">{{ row.name }}<br><span class="muted">{{ row.count > 1 ? $t('{0} agents', [row.count]) : $t('{0} agent', [row.count]) }}</span></th>
            <td v-for="c in CATEGORIES" :key="c">{{ num(row[c]) }}</td>
            <td class="pay-total">{{ num(row.total) }}</td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <th scope="row">{{ $t('Organisation') }}</th>
            <td v-for="c in CATEGORIES" :key="c">{{ num(totals[c]) }}</td>
            <td class="pay-total">{{ num(totals.total) }}</td>
          </tr>
        </tfoot>
      </table>
    </div>
    <p class="small muted">{{ $t('Heures, faites glisser le tableau pour voir toutes les colonnes.') }}</p>
  </section>
</template>

<script>
import { CATEGORIES } from '@/ui/payroll.js'

// Heures du mois par service (équipe), catégorie par catégorie, avec le total de l'organisation.
export default {
  name: 'PayTable',
  props: { rows: { type: Array, required: true }, totals: { type: Object, required: true }, labels: { type: Object, required: true }, num: { type: Function, required: true } },
  data: () => ({ CATEGORIES }),
}
</script>
