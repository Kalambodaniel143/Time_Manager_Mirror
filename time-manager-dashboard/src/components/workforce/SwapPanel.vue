<template>
  <section class="card section-card page-stack"><header><h2 class="card-title">{{ $t("Échanges de gardes") }}</h2><button class="btn btn-outline btn-sm" :disabled="loading || busy" @click="load">{{ $t("Actualiser") }}</button></header><p v-if="error" class="field-error" role="alert">{{ $t(error) }}</p><p v-if="loading" role="status">{{ $t("Chargement…") }}</p><p v-else-if="!error && !items.length" class="muted">{{ $t("Aucun échange demandé.") }}</p><article v-for="item in items" :key="item.id" class="request"><strong>{{ $t("Agents") }} {{ item.user_id }} {{ $t("et") }} {{ item.target_user_id }}</strong><p>{{ item.reason }}</p><p class="field-hint">{{ stamp(item.proposal.source.start) }} ↔ {{ stamp(item.proposal.target.start) }} {{ $t("UTC") }}</p><span class="pill">{{ $t(statuses[item.status]) }}</span><p v-if="item.review_reason">{{ item.review_reason }}</p><div v-if="item.target_user_id === currentId && item.status === 'pending'" class="actions"><button class="btn btn-primary btn-sm" :disabled="busy" @click="consent(item, true)">{{ $t("Je suis d’accord") }}</button><button class="btn btn-outline btn-sm" :disabled="busy" @click="consent(item, false)">{{ $t("Refuser") }}</button></div><div v-else-if="canReview && mayReview(item.user_id) && mayReview(item.target_user_id) && item.status === 'consented'" class="actions"><button class="btn btn-primary btn-sm" :disabled="busy" @click="decide(item, 'approved', '')">{{ $t("Valider l’échange") }}</button><button class="btn btn-outline btn-sm" :disabled="busy" @click="target = item; reason = ''">{{ $t("Refuser") }}</button></div></article><ModalDialog v-if="target" :title="$t(&quot;Refuser l’échange&quot;)" id="swap-refusal" :busy="busy" @close="target = null"><label class="field"><span class="field-label">{{ $t("Motif") }}</span><textarea v-model.trim="reason" class="input" maxlength="500" /></label><p v-if="error" class="field-error" role="alert">{{ $t(error) }}</p><button class="btn btn-danger" :disabled="busy || !reason" @click="decide(target, 'rejected', reason)">{{ $t("Confirmer") }}</button></ModalDialog></section>
</template>
<script>
import ModalDialog from '../ui/ModalDialog.vue'
import { auth } from '../../stores/auth'
import { listSwaps, consentSwap, reviewSwap, canReviewTarget } from '../../services/workforceService'
import { formatClockDate } from '../../utils/clockDate'
export default {
  name: 'SwapPanel', components: { ModalDialog }, props: { canReview: Boolean, refreshKey: { type: Number, default: 0 } }, emits: ['changed'],
  data() { return { items: [], loading: false, busy: false, error: '', version: 0, target: null, reason: '', statuses: { pending: 'Accord du collègue attendu', consented: 'Décision du responsable attendue', approved: 'Échange effectué', rejected: 'Refusé' } } },
  computed: { currentId() { return auth.user?.id } }, watch: { refreshKey() { this.load() } }, created() { this.load() }, beforeUnmount() { this.version += 1 },
  methods: {
    stamp: formatClockDate, mayReview: canReviewTarget,
    async load() { const version = ++this.version; this.loading = true; this.error = ''; try { const items = await listSwaps(); if (version === this.version) this.items = items } catch (error) { if (version === this.version) this.error = error.message } finally { if (version === this.version) this.loading = false } },
    async run(action) { if (this.busy) return; this.busy = true; this.error = ''; try { await action(); this.target = null; await this.load(); this.$emit('changed') } catch (error) { this.error = error.message } finally { this.busy = false } },
    consent(item, accepted) { return this.run(() => consentSwap(item.id, accepted)) },
    decide(item, status, reason) { return this.run(() => reviewSwap(item.id, status, reason)) },
  },
}
</script>
<style scoped>
header,.actions { display: flex; gap: 12px; justify-content: space-between; flex-wrap: wrap; }
.request { display: flex; flex-direction: column; gap: 8px; padding-top: 16px; border-top: 1px solid var(--border); }
</style>
