<template>
  <ul class="list card plan-list">
    <li v-for="day in days" :key="day.key ?? day.date" class="plan-row" :class="{ today: day.date === today }">
      <strong class="plan-day">{{ shortDay(`${day.date}T12:00`) }}</strong>
      <span class="plan-slot">
        <span class="tag" :class="`tag-${day.type}`">{{ SHIFT_LABELS[day.type] }}<template v-if="day.date === today"> {{ $t('· Aujourd’hui') }}</template></span>
        <span v-if="day.start" class="small muted">{{ day.start }} – {{ day.end }}<template v-if="day.place"> · {{ day.place }}</template></span>
      </span>
    </li>
  </ul>
</template>

<script>
import { SHIFT_LABELS } from '@/ui/shifts.js'
import { shortDay } from '@/ui/format.js'
import { localDay } from '@/ui/dates.js'

// Liste des gardes d'une semaine : { date: 'AAAA-MM-JJ', type, start, end, place? }.
export default {
  name: 'PlanningList',
  props: { days: { type: Array, required: true } },
  data: () => ({ SHIFT_LABELS, today: localDay(new Date()) }),
  methods: { shortDay },
}
</script>
