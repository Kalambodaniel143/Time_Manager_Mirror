<template>
  <div class="dates">
    <label>Début <input type="datetime-local" :value="modelValue.start" required @input="update('start', $event)" /></label>
    <label>Fin <input type="datetime-local" :value="modelValue.end" :min="modelValue.start" required @input="update('end', $event)" /></label>
  </div>
</template>

<script>
// Début et fin d'une période, avec le sélecteur natif date + heure du téléphone (heure locale).
export default {
  name: 'PeriodFields',
  props: { modelValue: { type: Object, required: true } },
  emits: ['update:modelValue'],
  methods: {
    update(field, event) { this.$emit('update:modelValue', { ...this.modelValue, [field]: event.target.value }) },
  },
}
</script>
