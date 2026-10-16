<template>
  <section v-if="receipt" class="card form-grid" role="status">
    <h2>{{ receipt.organization_name }}</h2>
    <p><span class="badge" :class="BADGES[receipt.status]">{{ LABELS[receipt.status] }}</span></p>
    <p v-if="receipt.status === 'approved'" class="small">{{ $t('Votre compte existe : connectez-vous avec votre e-mail et le mot de passe transmis par le super administrateur.') }}</p>
    <p v-if="receipt.rejection_reason" class="small">{{ $t('Motif : {0}', [receipt.rejection_reason]) }}</p>
    <p class="small muted">{{ $t('Référence de suivi à conserver :') }}</p>
    <code class="reference">{{ receipt.reference }}</code>
    <p v-if="error" class="field-error" role="alert">{{ error }}</p>
    <button type="button" class="btn-outline" :disabled="busy" @click="refresh(receipt.reference)">{{ $t('Actualiser le statut') }}</button>
    <button type="button" class="btn-quiet" @click="dismiss">{{ $t('Nouvelle demande') }}</button>
  </section>

  <form v-else-if="tracking" class="form-grid auth-form" @submit.prevent="refresh(reference)">
    <h2>{{ $t('Suivre ma demande') }}</h2>
    <label for="reference">{{ $t('Référence de suivi') }}</label>
    <input id="reference" v-model.trim="reference" required autocomplete="off" />
    <p v-if="error" class="field-error" role="alert">{{ error }}</p>
    <button type="submit" :disabled="busy">{{ $t('Voir le statut') }}</button>
    <button type="button" class="btn-quiet" @click="tracking = false">{{ $t('Revenir à la demande') }}</button>
  </form>

  <form v-else class="form-grid auth-form" @submit.prevent="send">
    <p class="small muted">{{ $t('Votre demande est adressée au super administrateur de {0}. Après son accord, vous rejoignez les services en tant qu’employé.', [ORGANIZATION_NAME]) }}</p>
    <ProfileFields v-model="profile" extended />
    <p class="small muted">{{ $t('Aucun mot de passe ici : le super administrateur vous en donnera un s’il accepte.') }}</p>
    <p v-if="error" class="field-error" role="alert">{{ error }}</p>
    <button type="submit" :disabled="busy">{{ $t('Envoyer ma demande') }}</button>
    <button type="button" class="btn-quiet" @click="tracking = true">{{ $t('Suivre ma demande') }}</button>
  </form>
</template>

<script>
import { t } from '@/i18n/index.js'
import ProfileFields from './ProfileFields.vue'
import { api } from '@/services/source.js'
import { forgetReferences, lastReference, saveReference } from '@/storage/joinRequests.js'
import { authError } from '@/ui/authErrors.js'
import { ORGANIZATION_NAME } from '@/config/api.js'

const LABELS = { pending: t('En attente'), approved: t('Acceptée'), rejected: t('Refusée') }
const BADGES = { pending: 'badge-warn', approved: 'badge-ok', rejected: 'badge-danger' }
const NOT_SET_UP = t('{0} n’est pas encore configurée. Contactez le super administrateur.', [ORGANIZATION_NAME])

// Comme « Rejoindre Gotham City » sur le web : l'organisation est retrouvée toute seule
// (GET /organizations/lookup), puis POST /join-requests ; suivi avec POST /join-requests/status.
export default {
  name: 'JoinPanel',
  components: { ProfileFields },
  data: () => ({
    receipt: null, tracking: false, reference: '', busy: false, error: '', ORGANIZATION_NAME, LABELS, BADGES,
    profile: { first_name: '', last_name: '', email: '', gender: 'unspecified', birth_date: '', birth_place: '' },
  }),
  created() {
    const saved = lastReference()
    if (saved) this.refresh(saved)
  },
  methods: {
    async attempt(task) {
      this.busy = true
      this.error = ''
      try { await task() } catch (error) { this.error = error.status === 404 && !this.tracking && !this.receipt ? NOT_SET_UP : authError(error) }
      finally { this.busy = false }
    },
    send() {
      return this.attempt(async () => {
        const organization = await api.lookupOrganization(ORGANIZATION_NAME)
        const receipt = await api.createJoinRequest({ organization_id: organization.id, profile: this.profile })
        saveReference(receipt.reference, receipt.organization_name)
        this.receipt = { ...receipt, rejection_reason: null }
      })
    },
    refresh(reference) {
      return this.attempt(async () => {
        this.receipt = await api.joinRequestStatus(reference)
        saveReference(reference, this.receipt.organization_name)
        this.tracking = false
      })
    },
    dismiss() {
      forgetReferences()
      Object.assign(this, { receipt: null, error: '' })
    },
  },
}
</script>
