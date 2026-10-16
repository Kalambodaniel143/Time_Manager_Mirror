<template>
  <span class="badge" :class="info.badge">{{ info.label }}</span>
</template>

<script>
import { statusOf } from '@/ui/statusLabels.js'

// Pastille d'état d'une demande ou d'une semaine (en attente, acceptée…).
export default {
  name: 'StatusBadge',
  props: { status: { type: String, default: '' } },
  computed: { info() { return statusOf(this.status) } },
}
</script>
