<template>
  <div class="form-grid">
    <SegmentedTabs v-model="decision" :options="CHOICES" :label="$t('Décision')" />
    <template v-if="decision === 'approve'">
      <label for="review-password">{{ $t('Mot de passe que vous lui transmettrez') }} <span class="muted small">({{ PASSWORD_RULE }})</span></label>
      <PasswordInput id="review-password" v-model="password" />
      <label for="review-confirm">{{ $t('Confirmer le mot de passe') }}</label>
      <PasswordInput id="review-confirm" v-model="confirm" />
    </template>
    <template v-else>
      <label for="review-reason">{{ $t('Motif du refus (visible par le demandeur)') }}</label>
      <textarea id="review-reason" v-model.trim="reason" rows="3" maxlength="500" />
    </template>
    <p v-if="error" class="field-error" role="alert">{{ error }}</p>
    <div class="request-actions">
      <button type="button" class="btn-outline" :disabled="busy" @click="$emit('cancel')">{{ $t('Annuler') }}</button>
      <button type="button" :class="{ 'btn-danger': decision === 'reject' }" :disabled="busy" @click="submit">
        {{ decision === 'approve' ? 'Accepter' : $t('Refuser') }}
      </button>
    </div>
  </div>
</template>

<script>
import { t } from '@/i18n/index.js'
import SegmentedTabs from '@/components/common/SegmentedTabs.vue'
import PasswordInput from '@/components/auth/PasswordInput.vue'
import { PASSWORD_RULE, validPassword } from '@/ui/authErrors.js'

// Décision sur une demande d'adhésion (même contrôle que le web : mot de passe confirmé, motif obligatoire).
export default {
  name: 'ReviewForm',
  components: { SegmentedTabs, PasswordInput },
  props: { busy: Boolean },
  emits: ['approve', 'reject', 'cancel'],
  data: () => ({
    decision: 'approve', password: '', confirm: '', reason: '', error: '', PASSWORD_RULE,
    CHOICES: [{ value: 'approve', label: t('Accepter') }, { value: 'reject', label: t('Refuser') }],
  }),
  methods: {
    submit() {
      this.error = ''
      if (this.decision === 'reject') {
        if (!this.reason) { this.error = t('Indiquez un motif de refus.'); return }
        this.$emit('reject', this.reason)
        return
      }
      if (!validPassword(this.password)) { this.error = t('Mot de passe : {0}', [PASSWORD_RULE]); return }
      if (this.password !== this.confirm) { this.error = t('Les mots de passe ne correspondent pas.'); return }
      this.$emit('approve', this.password)
      this.password = this.confirm = ''
    },
  },
}
</script>
