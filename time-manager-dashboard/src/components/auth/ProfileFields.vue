<template>
  <div class="profile-fields">
    <label v-for="field in fields" :key="field.key" class="field" :class="{ wide: field.key === 'email' }">
      <span :id="`profile-${field.key}-label`" class="field-label">{{ field.label }}</span>
      <input
        :value="modelValue[field.key]" class="input" :type="field.type || 'text'"
        :autocomplete="field.autocomplete" :maxlength="field.key === 'email' ? 254 : 100"
        :aria-labelledby="`profile-${field.key}-label`"
        :aria-invalid="Boolean(errors[field.key])" :aria-describedby="errors[field.key] ? `profile-${field.key}-error` : undefined"
        required @input="update(field.key, $event.target.value)"
      />
      <span v-if="errors[field.key]" :id="`profile-${field.key}-error`" class="field-error">{{ errors[field.key] }}</span>
    </label>
    <label v-if="personalDetails" class="field">
      <span id="profile-birth-label" class="field-label">Date de naissance</span>
      <input :value="modelValue.birth_date" class="input" type="date" min="1900-01-01" :max="today" autocomplete="bday" required aria-labelledby="profile-birth-label" :aria-invalid="Boolean(errors.birth_date)" :aria-describedby="errors.birth_date ? 'profile-birth-error' : undefined" @input="update('birth_date', $event.target.value)" />
      <span v-if="errors.birth_date" id="profile-birth-error" class="field-error">{{ errors.birth_date }}</span>
    </label>
    <label v-if="personalDetails" class="field">
      <span id="profile-gender-label" class="field-label">Genre</span>
      <select :value="modelValue.gender" class="input" required aria-labelledby="profile-gender-label" :aria-invalid="Boolean(errors.gender)" :aria-describedby="errors.gender ? 'profile-gender-error' : undefined" @change="update('gender', $event.target.value)">
        <option disabled value="">Choisir une réponse</option>
        <option v-for="gender in genders" :key="gender.value" :value="gender.value">{{ gender.label }}</option>
      </select>
      <span v-if="errors.gender" id="profile-gender-error" class="field-error">{{ errors.gender }}</span>
    </label>
  </div>
</template>

<script>
import { GENDERS, today } from '../../utils/registration'

export default {
  name: 'ProfileFields',
  props: { modelValue: { type: Object, required: true }, errors: { type: Object, default: () => ({}) }, personalDetails: { type: Boolean, default: true } },
  emits: ['update:modelValue'],
  data() {
    return {
      genders: GENDERS, today: today(),
      profileFields: [
        { key: 'first_name', label: 'Prénom', autocomplete: 'given-name' },
        { key: 'last_name', label: 'Nom', autocomplete: 'family-name' },
        { key: 'email', label: 'Adresse email', type: 'email', autocomplete: 'email' },
        { key: 'birth_place', label: 'Lieu de naissance', autocomplete: 'off' },
      ],
    }
  },
  computed: {
    fields() { return this.profileFields.filter((field) => this.personalDetails || field.key !== 'birth_place') },
  },
  methods: { update(key, value) { this.$emit('update:modelValue', { ...this.modelValue, [key]: value }) } },
}
</script>

<style scoped>
.profile-fields { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px; }
.wide { grid-column: 1 / -1; }
@media (max-width: 560px) { .profile-fields { grid-template-columns: 1fr; } }
</style>
