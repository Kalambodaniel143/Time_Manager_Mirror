<template>
  <div class="clock-actions">
    <button v-for="action in actions" :key="action.kind" type="button"
      :disabled="disabled || !allowedKinds.includes(action.kind)"
      @click="$emit('record', action.kind)">
      {{ action.label }}
    </button>
  </div>
</template>

<script>
// Messline affichera les actions autorisées calculées par le service de Jonas.
export default {
  name: 'ClockActions',
  props: {
    disabled: { type: Boolean, default: true },
    allowedKinds: { type: Array, default: () => [] },
  },
  emits: ['record'],
  data() {
    return {
      actions: [
        { kind: 'arrival', label: 'Arrivée' },
        { kind: 'departure', label: 'Départ' },
        { kind: 'pause', label: 'Pause' },
        { kind: 'resume', label: 'Reprise' },
      ],
    }
  },
}
</script>
