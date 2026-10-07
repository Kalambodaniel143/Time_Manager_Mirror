<template>
 <ModalDialog title="Proposer une correction" id="correction-title" :busy="busy" @close="$emit('close')">
  <p>Vos horaires restent inchangés jusqu’à l’accord de votre responsable. La proposition et la décision seront conservées.</p>
  <p class="field-hint">Une erreur de plus de sept jours peut aussi faire l’objet d’une demande de régularisation.</p>
  <form class="page-stack" novalidate @submit.prevent="send">
   <label class="field"><span class="field-label">Arrivée réelle</span><input v-model="start" class="input" type="datetime-local" step="1" required /></label>
   <label class="field"><span class="field-label">Départ réel</span><input v-model="end" class="input" type="datetime-local" step="1" required /></label>
   <label class="field"><span class="field-label">Motif de la correction</span><textarea v-model.trim="reason" class="input" rows="3" maxlength="500" required /></label>
   <p v-if="error" class="field-error" role="alert">{{ error }}</p>
   <button class="btn btn-primary" type="submit" :disabled="busy">{{ busy ? 'Envoi…' : 'Envoyer la proposition' }}</button>
  </form>
 </ModalDialog>
</template>
<script>
import ModalDialog from '../ui/ModalDialog.vue'
import { requestCorrection } from '../../services/correctionService'
import { clockDate, localDateInput } from '../../utils/missingDeparture'
import { formatClockDate } from '../../utils/clockDate'
export default {
 name: 'CorrectionRequest', components: { ModalDialog }, props: { entry: { type: Object, required: true } }, emits: ['close', 'sent'],
 data() { return { start: localDateInput(clockDate(this.entry.start)), end: localDateInput(clockDate(this.entry.end)), reason: '', busy: false, error: '' } },
 methods: {
  async send() {
   if (this.busy) return
   const from = new Date(this.start), to = new Date(this.end)
   if (!this.reason || !Number.isFinite(from.getTime()) || !Number.isFinite(to.getTime()) || to <= from || to > new Date()) { this.error = 'Indiquez des horaires réels cohérents, sans date future, et un motif.'; return }
   this.busy = true; this.error = ''
   try { await requestCorrection(this.entry.id, { start: formatClockDate(from), end: formatClockDate(to), reason: this.reason }); this.$emit('sent'); this.$emit('close') }
   catch (error) { this.error = error.status === 404 ? 'Les demandes de correction ne sont pas encore disponibles sur le serveur. Contactez votre responsable.' : error.message }
   finally { this.busy = false }
  },
 },
}
</script>
