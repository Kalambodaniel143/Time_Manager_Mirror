<template>
  <article class="card form-grid">
    <p class="row"><strong>{{ title }}</strong><StatusBadge :status="status" /></p>
    <p v-for="line in lines" :key="line" class="small muted">{{ line }}</p>
    <template v-if="open">
      <label :for="`reason-${id}`">{{ $t('Commentaire') }} <span class="small muted">{{ $t('(obligatoire pour refuser)') }}</span></label>
      <textarea :id="`reason-${id}`" v-model.trim="reason" rows="2" maxlength="500" />
      <template v-if="withHours">
        <label :for="`hours-${id}`">{{ $t('Heures rémunérables') }} <span class="small muted">{{ $t('(facultatif)') }}</span></label>
        <input :id="`hours-${id}`" v-model="hours" type="number" min="0" step="0.5" inputmode="decimal" />
      </template>
      <div class="request-actions">
        <button type="button" :disabled="busy" @click="$emit('decide', { status: 'approved', reason, hours })">{{ $t('Accepter') }}</button>
        <button type="button" class="btn-danger" :disabled="busy || !reason" @click="$emit('decide', { status: 'rejected', reason, hours })">{{ $t('Refuser') }}</button>
      </div>
    </template>
    <button v-else type="button" class="btn-outline btn-block" @click="open = true">{{ $t('Examiner') }}</button>
  </article>
</template>

<script>
import StatusBadge from '@/components/common/StatusBadge.vue'

// Carte de décision commune (corrections, absences, échanges) : accepter / refuser avec motif.
export default {
  name: 'DecisionCard',
  components: { StatusBadge },
  props: {
    id: { type: [String, Number], required: true },
    title: { type: String, required: true },
    lines: { type: Array, default: () => [] },
    status: { type: String, default: 'pending' },
    withHours: Boolean,
    busy: Boolean,
  },
  emits: ['decide'],
  data: () => ({ open: false, reason: '', hours: '' }),
}
</script>
