<template>
  <ul class="list card">
    <li v-for="day in days" :key="day.date" class="row" :class="{ today: day.date === today }">
      <strong>{{ shortDay(`${day.date}T12:00`) }}</strong>
      <span class="planning-slot">
        <span class="tag" :class="`tag-${day.type}`">{{ SHIFT_LABELS[day.type] }}</span>
        <span v-if="day.start" class="muted">{{ day.start }} – {{ day.end }}</span>
      </span>
    </li>
  </ul>
</template>

<script>
import { SHIFT_LABELS } from '@/ui/shifts.js'
import { shortDay } from '@/ui/format.js'
import { localDay } from '@/ui/dates.js'

// Liste des jours d'une semaine : { date: 'AAAA-MM-JJ', type, start, end }.
export default {
  name: 'PlanningList',
  props: { days: { type: Array, required: true } },
  data: () => ({ SHIFT_LABELS, today: localDay(new Date()) }),
  methods: { shortDay },
}
</script>
