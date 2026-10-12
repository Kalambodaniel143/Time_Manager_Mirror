<template>
  <section class="card">
    <div class="profile">
      <span class="avatar" aria-hidden="true">{{ initials(displayName(user)) }}</span>
      <span><strong>{{ displayName(user) }}</strong><br><span class="muted small">{{ ROLE_LABELS[user.role] }} · {{ user.email }}</span><br><span v-if="organization" class="muted small">{{ organization.name }}</span></span>
    </div>
    <button v-if="!editing" type="button" class="btn-quiet" @click="start">Modifier mes informations</button>
    <form v-else class="form-grid" @submit.prevent="save">
      <div class="dates">
        <label>Prénom <input v-model.trim="form.first_name" autocomplete="given-name" maxlength="100" /></label>
        <label>Nom <input v-model.trim="form.last_name" autocomplete="family-name" maxlength="100" /></label>
      </div>
      <label for="username">Nom d’utilisateur</label>
      <input id="username" v-model.trim="form.username" required autocomplete="name" />
      <label for="user-email">Adresse e-mail</label>
      <input id="user-email" v-model.trim="form.email" type="email" required autocomplete="email" />
      <p v-if="message" class="notice-danger small" role="alert">{{ message }}</p>
      <div class="row">
        <button type="button" class="btn-outline" @click="editing = false">Annuler</button>
        <button type="submit" :disabled="busy">Enregistrer</button>
      </div>
    </form>
  </section>
</template>

<script>
import { app } from '@/services/appState.js'
import { updateProfile } from '@/services/manageService.js'
import { ROLE_LABELS, displayName, initials } from '@/ui/format.js'

// Identité de l'utilisateur, modifiable (nom et e-mail, comme sur le web).
export default {
  name: 'ProfileCard',
  data: () => ({ editing: false, busy: false, message: '', form: {}, ROLE_LABELS }),
  computed: { user: () => app.user, organization: () => app.organization },
  methods: {
    initials, displayName,
    start() {
      const { first_name: first = '', last_name: last = '', username, email } = this.user
      this.form = { first_name: first ?? '', last_name: last ?? '', username, email }
      this.message = ''
      this.editing = true
    },
    async save() {
      this.busy = true
      try { await updateProfile(this.form); this.editing = false } catch (error) { this.message = error.message }
      finally { this.busy = false }
    },
  },
}
</script>
