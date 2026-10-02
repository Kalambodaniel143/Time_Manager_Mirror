<template>
  <span class="tag" :class="`tag-${kind}`">
    <AppIcon v-if="icon" :name="icon" />
    {{ label }}
    <span v-if="hours !== null" class="tag-hours num">{{ hoursLabel }}</span>
  </span>
</template>

<script>
import AppIcon from './AppIcon.vue'
import { KIND_ICONS, KIND_LABELS, KIND_SHORT, formatHours } from '../../utils/hours'

export default {
  name: 'HourTag',

  components: { AppIcon },

  props: {
    kind: { type: String, required: true },
    hours: { type: Number, default: null },
    short: { type: Boolean, default: false },
  },

  computed: {
    label() {
      return this.short ? KIND_SHORT[this.kind] : KIND_LABELS[this.kind]
    },

    icon() {
      return KIND_ICONS[this.kind] || null
    },

    hoursLabel() {
      return formatHours(this.hours)
    },
  },
}
</script>
