<template>
  <div class="week-bar">
    <div class="track" role="img" :aria-label="ariaLabel">
      <span
        v-for="segment in segments"
        :key="segment.kind"
        class="segment"
        :class="`segment-${segment.kind}`"
        :style="{ width: `${segment.width}%` }"
        :title="`${segment.label} · ${segment.hoursLabel}`"
      ></span>
      <span v-if="hasTarget" class="target" :style="{ left: `calc(${(target / scale) * 100}% - 3px)` }" aria-hidden="true"></span>
    </div>
    <p class="caption">{{ totalLabel }} enregistrées<template v-if="hasTarget"> · seuil d’heures supplémentaires : {{ targetLabel }} / semaine.</template><template v-else> · répartition jour/nuit estimée d’après les horaires, sans calcul de paie.</template></p>
    <div class="legend">
      <HourTag v-for="segment in legend" :key="segment.kind" :kind="segment.kind" :hours="segment.hours" />
    </div>
  </div>
</template>

<script>
import HourTag from './HourTag.vue'
import { KIND_LABELS, formatHours } from '../../utils/hours'
import { isDemoData } from '../../services/orgService'

const ORDER = ['day', 'night', 'oncall', 'sup']

export default {
  name: 'WeekBar',

  components: { HourTag },

  props: {
    buckets: { type: Object, required: true },
    target: { type: Number, default: 40 },
  },

  computed: {
    hasTarget() { return Number.isFinite(this.target) && this.target > 0 },
    scale() {
      return Math.max(this.hasTarget ? this.target : 0, this.buckets.total || 0, 1)
    },

    legend() {
      return ORDER.filter((kind) => this.buckets[kind] > 0).map((kind) => ({ kind, hours: this.buckets[kind] }))
    },

    segments() {
      return this.legend.map((item) => ({
        ...item,
        label: isDemoData() ? KIND_LABELS[item.kind] : { day: 'Jour', night: 'Nuit', oncall: 'Astreinte', sup: 'Heures supplémentaires' }[item.kind],
        hoursLabel: formatHours(item.hours),
        width: (item.hours / this.scale) * 100,
      }))
    },

    totalLabel() {
      return formatHours(this.buckets.total || 0)
    },

    targetLabel() {
      return formatHours(this.target)
    },

    ariaLabel() {
      return this.segments.map((segment) => `${segment.label} ${segment.hoursLabel}`).join(', ') || 'Aucune heure'
    },
  },
}
</script>

<style scoped>
.track {
  position: relative;
  display: flex;
  height: 24px;
  background: var(--surface);
  border: 1.5px solid var(--input-border);
  border-radius: 2px;
  overflow: visible;
}

.segment {
  height: 100%;
  border-right: 2px solid var(--surface);
}

.segment-day { background: var(--day-bar); }
.segment-night { background: var(--night-bar); }
.segment-oncall { background: var(--oncall-bar); }
.segment-sup { background: var(--sup-bar); }

.target {
  position: absolute;
  top: -6px;
  bottom: -6px;
  width: 3px;
  background: var(--text);
}

.caption {
  margin-top: 10px;
  font-size: 13.5px;
  color: var(--text-muted);
}

.legend {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}
</style>
