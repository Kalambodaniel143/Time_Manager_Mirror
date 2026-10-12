<template>
  <p v-for="m in alerts" :key="`alert-${m.id}`" class="card notice-card">
    ⚠️ <strong>{{ displayName(m) }}</strong> · {{ m.nights }} nuits d’affilée, au-delà du seuil de {{ NIGHT_LIMIT }}.
  </p>
  <ul class="list card">
    <li v-for="m in rows" :key="m.id">
      <RouterLink class="row member-link" :to="{ name: 'member', params: { id: m.id } }">
        <span><strong>{{ displayName(m) }}</strong><br><span class="muted small">{{ m.sub }}</span></span>
        <span>{{ m.total }} ›</span>
      </RouterLink>
    </li>
  </ul>
</template>

<script>
import { stats } from '@/ui/aggregate.js'
import { maxConsecutiveNights } from '@/ui/shifts.js'
import { displayName, hours } from '@/ui/format.js'

const NIGHT_LIMIT = 2 // protection des agents : plus de 2 nuits d'affilée est signalé

// Agents de l'équipe sur la période ; un appui ouvre leur tableau de bord.
// members = [{ id, username, periods }] (periods = null si heures indisponibles)
export default {
  name: 'MemberList',
  props: { members: { type: Array, required: true }, range: { type: Object, required: true } },
  data: () => ({ NIGHT_LIMIT }),
  methods: { displayName },
  computed: {
    rows() {
      return this.members.map((m) => {
        if (!m.periods) return { ...m, sub: 'Heures indisponibles', total: '—' }
        const s = stats(m.periods, this.range.from, this.range.to)
        return { ...m, sub: `${s.days} jours travaillés`, total: hours(s.total) }
      })
    },
    alerts() {
      const { from, to } = this.range
      return this.members
        .map((m) => ({ ...m, nights: maxConsecutiveNights((m.periods ?? []).filter((p) => p.start >= from && p.start <= to)) }))
        .filter((m) => m.nights > NIGHT_LIMIT)
    },
  },
}
</script>
