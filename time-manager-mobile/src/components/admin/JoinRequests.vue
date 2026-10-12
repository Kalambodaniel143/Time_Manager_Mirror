<template>
  <section class="card form-grid">
    <h2>Demandes à examiner · {{ pending.length }}</h2>
    <p class="small muted">Une personne n’accède à l’organisation qu’après votre accord.</p>
    <p v-if="error" class="notice-danger small" role="alert">{{ error }}</p>
    <p v-if="created" class="notice-ok small" role="status">
      Compte créé pour <strong>{{ created.email }}</strong>. Transmettez-lui ce mot de passe : <strong>{{ created.password }}</strong>
      (il ne sera plus affiché).
    </p>
    <p v-if="!pending.length" class="muted small">Aucune demande en attente.</p>
    <article v-for="r in pending" :key="r.id" class="request">
      <p><strong>{{ r.profile.first_name }} {{ r.profile.last_name }}</strong> <span class="badge badge-warn">En attente</span><br>
        <span class="small muted">{{ r.profile.email }} · {{ GENDERS[r.profile.gender] ?? '' }} · né(e) le {{ date(r.profile.birth_date) }} à {{ r.profile.birth_place }}</span></p>
      <ReviewForm v-if="open === r.id" :busy="busy" @approve="approve(r, $event)" @reject="reject(r, $event)" @cancel="open = null" />
      <button v-else type="button" class="btn-outline btn-block" @click="start(r)">Examiner la demande</button>
    </article>
    <template v-if="history.length">
      <h3 class="small">Demandes traitées</h3>
      <ul class="list flush">
        <li v-for="r in history" :key="r.id" class="row">
          <span>{{ r.profile.first_name }} {{ r.profile.last_name }}<br><span class="small muted">{{ r.rejection_reason || r.profile.email }}</span></span>
          <span class="badge" :class="r.status === 'approved' ? 'badge-ok' : 'badge-danger'">{{ r.status === 'approved' ? 'Acceptée' : 'Refusée' }}</span>
        </li>
      </ul>
    </template>
  </section>
</template>

<script>
import ReviewForm from './ReviewForm.vue'
import { app } from '@/services/appState.js'
import { api } from '@/services/source.js'
import { authError } from '@/ui/authErrors.js'

const GENDERS = { female: 'Femme', male: 'Homme', non_binary: 'Non binaire', unspecified: 'Non précisé' }

// Demandes d'adhésion : accepter (mot de passe choisi par l'admin) ou refuser (motif).
// Le mot de passe n'est affiché qu'une fois, puis oublié par l'application.
export default {
  name: 'JoinRequests',
  components: { ReviewForm },
  emits: ['changed', 'count'],
  data: () => ({ requests: [], open: null, busy: false, error: '', created: null, GENDERS }),
  computed: {
    pending() { return this.requests.filter((r) => r.status === 'pending') },
    history() { return this.requests.filter((r) => r.status !== 'pending') },
  },
  created() { this.load() },
  methods: {
    date: (value) => (value ? new Date(`${value.slice(0, 10)}T12:00`).toLocaleDateString('fr-FR') : '—'),
    async load() {
      try {
        this.requests = await api.listJoinRequests(app.organization.id)
        this.$emit('count', this.pending.length)
      } catch (error) {
        this.error = authError(error)
      }
    },
    start(request) { Object.assign(this, { open: request.id, created: null, error: '' }) },
    async act(task) {
      this.busy = true
      this.error = ''
      try { await task(); this.open = null; await this.load(); this.$emit('changed') }
      catch (error) { this.error = authError(error) }
      finally { this.busy = false }
    },
    approve(r, password) {
      return this.act(async () => {
        await api.approveJoinRequest(app.organization.id, r.id, password)
        this.created = { email: r.profile.email, password }
      })
    },
    reject(r, reason) { return this.act(() => api.rejectJoinRequest(app.organization.id, r.id, reason)) },
  },
}
</script>
