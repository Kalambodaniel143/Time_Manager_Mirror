<template>
  <form class="form-grid" @submit.prevent="submit">
    <label :for="`shift-member-${uid}`">{{ $t('Agent') }}</label>
    <select :id="`shift-member-${uid}`" v-model="form.user_id" required>
      <option v-for="m in members" :key="m.id" :value="m.id">{{ displayName(m) }}</option>
    </select>
    <label :for="`shift-start-${uid}`">{{ $t('Début') }}</label>
    <input :id="`shift-start-${uid}`" v-model="form.start" type="datetime-local" required />
    <label :for="`shift-end-${uid}`">{{ $t('Fin') }}</label>
    <input :id="`shift-end-${uid}`" v-model="form.end" type="datetime-local" required />
    <label :for="`shift-kind-${uid}`">{{ $t('Type') }}</label>
    <select :id="`shift-kind-${uid}`" v-model="form.kind">
      <option v-for="(label, value) in SHIFT_KINDS" :key="value" :value="value">{{ label }}</option>
    </select>
    <label :for="`shift-place-${uid}`">{{ $t('Lieu') }}</label>
    <input :id="`shift-place-${uid}`" v-model.trim="form.place" :placeholder="$t('Ex. : Centre')" />
    <p v-if="error" class="field-error" role="alert">{{ error }}</p>
    <div :class="{ 'request-actions': initial }">
      <button type="submit" :disabled="busy || !form.user_id" :class="{ 'btn-block': !initial }">{{ initial ? 'Enregistrer' : $t('Ajouter au brouillon') }}</button>
      <button v-if="initial" type="button" class="btn-outline" @click="$emit('cancel')">{{ $t('Annuler') }}</button>
    </div>
  </form>
</template>

<script>
import { t } from '@/i18n/index.js'
import { SHIFT_KINDS } from '@/ui/statusLabels.js'
import { displayName } from '@/ui/format.js'
import { fromInput, toInput } from '@/ui/weeks.js'

let next = 0

// Créneau d'un planning : ajout, ou modification si « initial » est fourni.
// Heures saisies en heure du téléphone, envoyées en UTC.
export default {
  name: 'ShiftForm',
  props: { members: { type: Array, required: true }, initial: { type: Object, default: null }, busy: Boolean },
  emits: ['save', 'cancel'],
  data() {
    const s = this.initial
    return {
      uid: ++next, error: '', SHIFT_KINDS,
      form: s ? { user_id: s.user_id, start: toInput(s.start), end: toInput(s.end), kind: s.kind, place: s.place ?? '' }
        : { user_id: null, start: '', end: '', kind: 'day', place: '' },
    }
  },
  methods: {
    displayName,
    submit() {
      const { user_id, kind, place, start, end } = this.form
      if (end <= start) { this.error = t('La fin doit être après le début.'); return }
      if (new Date(start) < new Date()) { this.error = t('Un créneau doit être dans le futur.'); return }
      if (new Date(end) - new Date(start) > 24 * 3_600_000) { this.error = t('Un créneau dure au plus 24 h.'); return }
      this.error = ''
      this.$emit('save', { user_id, kind, place, start: fromInput(start), end: fromInput(end) })
    },
  },
}
</script>
