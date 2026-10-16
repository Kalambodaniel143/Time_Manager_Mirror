<template>
  <section class="last-week card">
    <header class="last-week-header">
      <h2 class="card-title">{{ $t(title) }}</h2>
      <span v-if="loading" class="skeleton total-skeleton"></span>
      <p v-else-if="!error" class="total serif num">{{ $t(totalLabel) }}</p>
    </header>
    <p v-if="error" class="field-error" role="alert">{{ $t("Impossible de charger les heures :") }} {{ $t(error) }}</p>
    <WeekBar v-else-if="!loading" :buckets="buckets" :target="target" />
  </section>
</template>

<script>
import WeekBar from '../ui/WeekBar.vue'
import { formatHours } from '../../utils/hours'

export default {
  name: 'LastWeekCard',

  components: { WeekBar },

  props: {
    title: { type: String, required: true },
    buckets: { type: Object, required: true },
    target: { type: Number, default: 40 },
    loading: { type: Boolean, default: false },
    error: { type: String, default: '' },
  },

  computed: {
    totalLabel() {
      return formatHours(this.buckets.total)
    },
  },
}
</script>

<style scoped>
.last-week {
  padding: 22px 24px 24px;
}

.last-week-header {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 14px;
}

.total {
  font-size: 28px;
  color: var(--text);
}

.total-skeleton {
  width: 90px;
  height: 44px;
}
</style>
