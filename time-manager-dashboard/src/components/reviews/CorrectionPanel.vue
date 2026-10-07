<template>
 <section class="card section-card corrections">
  <header><h2 class="card-title">{{ canReview ? 'Corrections à examiner' : 'Mes demandes de correction' }}</h2><button class="btn btn-quiet btn-sm" type="button" :disabled="loading" @click="load">Actualiser</button></header>
  <p v-if="loading" class="muted" role="status">Chargement…</p><p v-else-if="error" class="field-hint" role="status">{{ error }}</p><p v-else-if="!items.length" class="muted">Aucune demande de correction.</p>
  <article v-for="item in items" :key="item.id" class="correction"><div class="correction-header"><strong>{{ canReview ? item.username : 'Période à corriger' }}</strong><span class="pill" :class="item.status === 'pending' ? 'pill-warn' : item.status === 'approved' ? 'pill-ok' : 'pill-danger'">{{ statuses[item.status] }}</span></div><p class="field-hint">Enregistré : {{ range(item.before) }}</p><p>Proposé : {{ range(item.proposal) }}</p><p class="muted">{{ item.reason }}</p><p v-if="item.reviewed_by" class="field-hint">Décision de {{ item.reviewed_by }} · {{ stamp(item.reviewed_at) }} {{ item.review_reason }}</p><div v-if="canReview && item.status === 'pending' && item.user_id !== currentUserId" class="actions"><button class="btn btn-primary btn-sm" type="button" @click="target = item; decision = 'approved'">Accepter</button><button class="btn btn-danger btn-sm" type="button" @click="target = item; decision = 'rejected'">Refuser</button></div></article>
  <ModalDialog v-if="target" :title="decision === 'approved' ? 'Accepter la correction' : 'Refuser la correction'" id="review-correction-title" :busy="busy" @close="target = null; reviewError = ''; reason = ''"><p>{{ target.reason }}</p><label class="field"><span class="field-label">{{ decision === 'rejected' ? 'Motif du refus' : 'Commentaire (facultatif)' }}</span><textarea v-model.trim="reason" class="input" rows="3" maxlength="500" /></label><p v-if="reviewError" class="field-error" role="alert">{{ reviewError }}</p><button class="btn btn-primary" type="button" :disabled="busy" @click="review">{{ busy ? 'Enregistrement…' : 'Confirmer la décision' }}</button></ModalDialog>
 </section>
</template>
<script>
import ModalDialog from '../ui/ModalDialog.vue'
import { auth } from '../../stores/auth'
import { listCorrections, reviewCorrection } from '../../services/correctionService'
import { clockDate } from '../../utils/missingDeparture'
export default {
 name: 'CorrectionPanel', components: { ModalDialog }, props: { userId: { type: [String, Number], default: null }, canReview: Boolean, refreshKey: { type: Number, default: 0 } }, emits: ['changed'],
 data() { return { items: [], loading: false, busy: false, error: '', target: null, decision: '', reason: '', reviewError: '', version: 0, statuses: { pending: 'En attente', approved: 'Acceptée', rejected: 'Refusée' } } },
 computed: { currentUserId() { return auth.user?.id } },
 watch: { userId: { immediate: true, handler() { this.load() } }, refreshKey() { this.load() } },
 beforeUnmount() { this.version += 1 },
 methods: {
  stamp(value) { return clockDate(value).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' }) },
  range(period) { return `${this.stamp(period.start)} → ${this.stamp(period.end)}` },
  async load() { const version = ++this.version; this.loading = true; this.error = ''; try { const items = await listCorrections(this.userId); if (version === this.version) this.items = items || [] } catch (error) { if (version === this.version) this.error = error.status === 404 ? 'Le suivi des corrections sera disponible après activation du service. Vous pouvez contacter votre responsable.' : error.message } finally { if (version === this.version) this.loading = false } },
  async review() { if (this.busy) return; if (this.decision === 'rejected' && !this.reason) { this.reviewError = 'Indiquez le motif du refus.'; return }; this.busy = true; this.reviewError = ''; try { await reviewCorrection(this.target.id, this.decision, this.reason); this.target = null; this.reason = ''; await this.load(); this.$emit('changed') } catch (error) { this.reviewError = error.message } finally { this.busy = false } },
 },
}
</script>
<style scoped>
header, .correction-header, .actions { display: flex; justify-content: space-between; align-items: center; gap: 8px; flex-wrap: wrap; }
.correction { display: flex; flex-direction: column; gap: 8px; padding-top: 16px; margin-top: 16px; border-top: 1px solid var(--border); overflow-wrap: anywhere; }
.corrections > p { margin-top: 12px; }
.actions { justify-content: flex-start; }
</style>
