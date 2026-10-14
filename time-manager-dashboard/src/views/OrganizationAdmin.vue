<template>
  <div class="organization-admin">
    <PageHeader :eyebrow="$t(session.organization.name)" :title="$t(&quot;Administration Gotham City&quot;)">
      <button class="btn btn-outline" type="button" :disabled="loading || busy" @click="load"><AppIcon name="rotate" />{{ $t("Actualiser") }}</button>
    </PageHeader>
    <InfoNote :title="$t(&quot;Le nom à communiquer à votre équipe&quot;)" flat> {{ $t("Les demandes sont rattachées automatiquement à Gotham City. Le super administrateur les examine et fournit le mot de passe après acceptation.") }} </InfoNote>
    <p v-if="error" class="field-error page-error" role="alert">{{ $t(error) }}</p>
    <p v-if="loading" class="loading-message" role="status">{{ $t("Chargement de votre organisation…") }}</p>
    <template v-else>
      <div class="summary">
        <div class="card metric"><AppIcon name="users" /><strong>{{ pending.length }}</strong><span>{{ $t("demande") }}{{ $t(pending.length > 1 ? 's' : '') }} {{ $t("en attente") }}</span></div>
        <div class="card metric"><AppIcon name="check-circle" /><strong>{{ members.length }}</strong><span>{{ $t("membre") }}{{ $t(members.length > 1 ? 's' : '') }}</span></div>
        <div class="card metric"><AppIcon name="shield" /><strong>{{ managerCount }}</strong><span>{{ $t("manager") }}{{ $t(managerCount > 1 ? 's' : '') }}</span></div>
      </div>

      <section class="card section">
        <h2 class="card-title">{{ $t("Demandes à examiner") }}</h2>
        <p class="card-subtitle">{{ $t("Un employé accède à votre organisation seulement après votre accord.") }}</p>
        <p v-if="!pending.length" class="empty">{{ $t("Aucune demande en attente. Les nouvelles demandes apparaîtront ici.") }}</p>
        <article v-for="request in pending" :key="request.id" class="request">
          <div class="request-heading"><div><h3>{{ request.profile.first_name }} {{ request.profile.last_name }}</h3><p class="muted">{{ request.profile.email }} · {{ date(request.created_at) }}</p></div><span class="pill pill-warn">{{ $t("En attente") }}</span></div>
          <dl class="details"><div><dt>{{ $t("Naissance") }}</dt><dd>{{ date(request.profile.birth_date) }}</dd></div><div><dt>{{ $t("Lieu") }}</dt><dd>{{ request.profile.birth_place }}</dd></div><div><dt>{{ $t("Genre") }}</dt><dd>{{ $t(gender(request.profile.gender)) }}</dd></div></dl>
          <div class="actions"><button class="btn btn-primary btn-sm" type="button" :disabled="busy" @click="startReview(request, 'approve')"><AppIcon name="check" />{{ $t("Accepter") }}</button><button class="btn btn-danger btn-sm" type="button" :disabled="busy" @click="startReview(request, 'reject')">{{ $t("Refuser") }}</button></div>
        </article>
      </section>

      <section class="card section">
        <h2 class="card-title">{{ $t("Membres et rôles") }}</h2>
        <p class="card-subtitle">{{ $t("Les personnes acceptées sont employées par défaut. Vous pouvez les promouvoir managers ou les repasser employés.") }}</p>
        <div class="table-wrap"><table class="table"><thead><tr><th scope="col">{{ $t("Membre") }}</th><th scope="col">{{ $t("Email") }}</th><th scope="col">{{ $t("Rôle") }}</th><th scope="col">{{ $t("Action") }}</th></tr></thead><tbody>
          <tr v-for="member in members" :key="member.id"><th scope="row">{{ member.first_name }} {{ member.last_name }}</th><td>{{ member.email }}</td><td><span class="badge" :class="member.role === 'admin' ? 'badge-accent' : 'badge-muted'">{{ $t(roleLabel(member.role)) }}</span></td><td><button v-if="member.role !== 'admin'" class="btn btn-outline btn-sm" type="button" :disabled="busy" @click="roleTarget = member">{{ $t(member.role === 'employee' ? 'Promouvoir manager' : 'Repasser employé') }}</button><span v-else class="muted">{{ $t("Super administrateur · compte créé manuellement") }}</span></td></tr>
        </tbody></table></div>
      </section>

      <section v-if="history.length" class="card section">
        <h2 class="card-title">{{ $t("Demandes traitées") }}</h2>
        <ul class="history"><li v-for="request in history" :key="request.id"><div><strong>{{ request.profile.first_name }} {{ request.profile.last_name }}</strong><p class="muted">{{ request.profile.email }} · {{ date(request.reviewed_at) }}</p><p v-if="request.rejection_reason">{{ request.rejection_reason }}</p></div><span class="pill" :class="request.status === 'approved' ? 'pill-ok' : 'pill-danger'">{{ $t(request.status === 'approved' ? 'Acceptée' : 'Refusée') }}</span></li></ul>
      </section>
    </template>

    <CorrectionPanel can-review />
    <Teleport to="body">
      <div v-if="review || credentials || roleTarget" class="overlay" @click.self="closeDialog">
        <form ref="dialog" class="dialog card review-dialog" role="dialog" aria-modal="true" aria-labelledby="review-title" tabindex="-1" novalidate @submit.prevent="submitDialog" @keydown="trapFocus">
          <header class="dialog-header"><div><p class="eyebrow">{{ session.organization.name }}</p><h2 id="review-title" class="card-title">{{ $t(dialogTitle) }}</h2></div><button class="btn btn-quiet btn-icon" type="button" :aria-label="$t(&quot;Fermer&quot;)" :disabled="busy" @click="closeDialog"><AppIcon name="close" /></button></header>
          <div class="dialog-body">
            <template v-if="credentials">
              <p>{{ $t(demo ? "Le compte employé est créé. Transmettez ces identifiants à" : "Le compte employé est créé. Les identifiants ont été envoyés par email à") }} {{ credentials.name }}.</p>
              <label class="field"><span class="field-label">{{ $t("Email de connexion") }}</span><input class="input" :value="credentials.email" readonly /></label>
              <label class="field"><span class="field-label">{{ $t("Mot de passe défini par vous") }}</span><input class="input" :type="showPassword ? 'text' : 'password'" :value="credentials.password" readonly /></label>
              <button class="link" type="button" @click="showPassword = !showPassword">{{ $t(showPassword ? 'Masquer' : 'Afficher') }} {{ $t("le mot de passe") }}</button>
              <p class="field-hint">{{ $t("Le mot de passe ne sera plus affiché après fermeture de cette fenêtre.") }}</p>
              <button class="btn btn-outline" type="button" @click="copyCredentials">{{ $t(copied ? 'Identifiants copiés' : 'Copier les identifiants') }}</button>
            </template>
            <template v-else-if="roleTarget">
              <p>{{ roleTarget.first_name }} {{ roleTarget.last_name }} {{ $t("deviendra") }} {{ $t(roleTarget.role === 'employee' ? 'manager' : 'employé') }} {{ $t("de votre organisation.") }}</p>
              <p class="field-hint">{{ $t("Ses identifiants restent identiques. Son nouvel accès est pris en compte à sa prochaine actualisation de session ou connexion.") }}</p>
            </template>
            <template v-else-if="review">
              <p><strong>{{ review.profile.first_name }} {{ review.profile.last_name }}</strong><br>{{ review.profile.email }}</p>
              <template v-if="decision === 'approve'">
                <p>{{ $t("Définissez le mot de passe que vous fournirez à cet employé.") }}</p>
                <label class="field"><span id="employee-password-label" class="field-label">{{ $t("Mot de passe employé") }}</span><input v-model="password" aria-labelledby="employee-password-label" class="input" :type="showPassword ? 'text' : 'password'" autocomplete="new-password" minlength="8" maxlength="128" required /><PasswordHint /></label>
                <button class="link" type="button" @click="showPassword = !showPassword">{{ $t(showPassword ? 'Masquer' : 'Afficher') }} {{ $t("le mot de passe") }}</button>
                <label class="field"><span class="field-label">{{ $t("Confirmer le mot de passe") }}</span><input v-model="confirmation" class="input" type="password" autocomplete="new-password" required /></label>
              </template>
              <label v-else class="field"><span class="field-label">{{ $t("Motif du refus") }}</span><textarea v-model.trim="reason" class="input" rows="3" maxlength="500" required></textarea><span class="field-hint">{{ $t("Ce motif est visible par le demandeur lors du suivi.") }}</span></label>
            </template>
            <p v-if="dialogError" class="field-error" role="alert">{{ $t(dialogError) }}</p>
          </div>
          <footer class="dialog-footer"><button class="btn btn-ghost" type="button" :disabled="busy" @click="closeDialog">{{ $t(credentials ? 'Fermer' : 'Annuler') }}</button><button v-if="!credentials" class="btn" :class="decision === 'reject' && !roleTarget ? 'btn-danger' : 'btn-primary'" type="submit" :disabled="busy">{{ $t(busy ? 'Enregistrement…' : roleTarget ? 'Confirmer le rôle' : decision === 'approve' ? 'Accepter et créer le compte' : 'Confirmer le refus') }}</button></footer>
        </form>
      </div>
    </Teleport>
  </div>
</template>

<script>
import { intlLocale } from '../utils/i18n.js'

import PasswordHint from '../components/auth/PasswordHint.vue'
import AppIcon from '../components/ui/AppIcon.vue'
import InfoNote from '../components/ui/InfoNote.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import CorrectionPanel from '../components/reviews/CorrectionPanel.vue'
import { AUTH_USE_MOCK, approveJoinRequest, listJoinRequests, listMembers, rejectJoinRequest, setMemberRole } from '../services/organizationService'
import { GENDERS, passwordError } from '../utils/registration'
import { notify } from '../utils/toast'

export default {
  name: 'OrganizationAdmin',
  components: { PasswordHint, CorrectionPanel, AppIcon, InfoNote, PageHeader },
  props: { session: { type: Object, required: true } },
  data() { return { requests: [], members: [], loading: false, busy: false, error: '', review: null, decision: '', password: '', confirmation: '', reason: '', dialogError: '', credentials: null, showPassword: false, copied: false, roleTarget: null, returnFocus: null } },
  computed: {
    demo() { return AUTH_USE_MOCK },
    pending() { return this.requests.filter((request) => request.status === 'pending') },
    history() { return this.requests.filter((request) => request.status !== 'pending') },
    managerCount() { return this.members.filter((member) => member.role === 'manager').length },
    dialogOpen() { return Boolean(this.review || this.credentials || this.roleTarget) },
    dialogTitle() { return this.credentials ? 'Identifiants à transmettre' : this.roleTarget ? 'Changer le rôle' : this.decision === 'approve' ? 'Accepter la demande' : 'Refuser la demande' },
  },
  watch: {
    'session.organization.id': { immediate: true, handler() { this.load() } },
    dialogOpen(open) {
      if (open) { this.returnFocus = document.activeElement; this.$nextTick(() => this.$refs.dialog?.focus()) }
      else this.returnFocus?.focus()
    },
  },
  beforeUnmount() { this.password = ''; this.confirmation = ''; this.credentials = null },
  methods: {
    async load() {
      this.loading = true
      this.error = ''
      try { [this.requests, this.members] = await Promise.all([listJoinRequests(this.session.organization.id), listMembers(this.session.organization.id)]) }
      catch (error) { this.error = error.message }
      finally { this.loading = false }
    },
    date(value) { return value ? new Date(value.length === 10 ? `${value}T12:00:00` : value).toLocaleDateString(intlLocale()) : '—' },
    gender(value) { return GENDERS.find((item) => item.value === value)?.label || '—' },
    roleLabel(role) { return { admin: 'Super administrateur', employee: 'Employé', manager: 'Manager' }[role] || role },
    startReview(request, decision) { this.review = request; this.decision = decision; this.dialogError = ''; this.password = ''; this.confirmation = ''; this.reason = ''; this.showPassword = false },
    closeDialog() {
      if (this.busy) return
      this.review = null; this.roleTarget = null; this.credentials = null; this.password = ''; this.confirmation = ''; this.reason = ''; this.dialogError = ''; this.showPassword = false; this.copied = false
    },
    trapFocus(event) {
      if (event.key === 'Escape') { event.preventDefault(); this.closeDialog() }
      if (event.key !== 'Tab') return
      const elements = [...this.$refs.dialog.querySelectorAll('button:not(:disabled), input, textarea, [tabindex="0"]')]
      const first = elements[0], last = elements.at(-1)
      if (event.shiftKey && (document.activeElement === first || document.activeElement === this.$refs.dialog)) { event.preventDefault(); last?.focus() }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus() }
    },
    async submitDialog() {
      if (this.busy || this.credentials) return
      this.dialogError = ''
      if (this.review && this.decision === 'approve') {
        const message = passwordError(this.password)
        if (message || this.password !== this.confirmation) { this.dialogError = message || 'Les mots de passe ne correspondent pas.'; return }
      } else if (this.review && !this.reason.trim()) { this.dialogError = 'Indiquez un motif de refus.'; return }
      this.busy = true
      try {
        const orgId = this.session.organization.id
        if (this.roleTarget) {
          await setMemberRole(orgId, this.roleTarget.id, this.roleTarget.role === 'employee' ? 'manager' : 'employee')
          this.roleTarget = null
          notify('Rôle mis à jour.')
        } else if (this.decision === 'approve') {
          const result = await approveJoinRequest(orgId, this.review.id, this.password)
          this.credentials = { email: result.user.email, password: this.password, name: `${result.user.first_name} ${result.user.last_name}` }
          this.password = ''; this.confirmation = ''; this.review = null
          notify('Demande acceptée. Le compte employé est créé.')
        } else {
          await rejectJoinRequest(orgId, this.review.id, this.reason)
          this.review = null; this.reason = ''
          notify('Demande refusée.')
        }
        await this.load()
      } catch (error) { this.dialogError = error.message }
      finally { this.busy = false }
    },
    async copyCredentials() {
      const text = `Organisation : ${this.session.organization.name}\nEmail : ${this.credentials.email}\nMot de passe : ${this.credentials.password}`

      try {
        if (navigator.clipboard?.writeText) {
          await navigator.clipboard.writeText(text)
        } else {
          this.copyTextFallback(text)
        }
        this.copied = true
        this.dialogError = ''
      } catch {
        this.dialogError = 'Copie indisponible. Vous pouvez sélectionner les identifiants manuellement.'
      }
    },
    copyTextFallback(text) {
      const textarea = document.createElement('textarea')
      textarea.value = text
      textarea.setAttribute('readonly', '')
      textarea.style.position = 'fixed'
      textarea.style.opacity = '0'
      document.body.appendChild(textarea)
      textarea.select()
      const copied = document.execCommand('copy')
      textarea.remove()
      if (!copied) throw new Error('copy_failed')
    },
  },
}
</script>

<style scoped>
.organization-admin { display: flex; flex-direction: column; gap: 22px; }
.organization-admin :deep(.page-header) { margin-bottom: 0; }
.summary { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 18px; }
.metric { display: grid; grid-template-columns: auto 1fr; column-gap: 16px; padding: 22px; }
.metric svg { grid-row: span 2; width: 32px; height: 32px; color: var(--title); align-self: center; }
.metric strong { font-size: 30px; color: var(--title); }
.metric span, .muted { color: var(--text-muted); }
.section { padding: 24px; }
.request { display: flex; flex-direction: column; gap: 16px; padding: 22px 0; border-top: 1px solid var(--border); }
.request:first-of-type { margin-top: 20px; }
.request-heading, .history li { display: flex; flex-wrap: wrap; align-items: flex-start; justify-content: space-between; gap: 12px; }
.details { display: flex; flex-wrap: wrap; gap: 16px 36px; margin: 0; }
.details dt { color: var(--text-muted); font-size: 13px; }
.details dd { margin: 3px 0 0; }
.actions { display: flex; flex-wrap: wrap; gap: 10px; }
.empty { padding: 28px 0 10px; color: var(--text-muted); }
.table-wrap { overflow-x: auto; margin-top: 18px; }
.history { padding: 0; margin: 20px 0 0; list-style: none; }
.history li { padding: 16px 0; border-top: 1px solid var(--border); }
.review-dialog { width: min(540px, 100%); }
.review-dialog .dialog-body { display: flex; flex-direction: column; gap: 16px; }
.review-dialog .dialog-body > .link { align-self: flex-start; }
.loading-message { color: var(--text-muted); }
@media (max-width: 650px) { .summary { grid-template-columns: 1fr; } .section { padding: 18px; } }
</style>
