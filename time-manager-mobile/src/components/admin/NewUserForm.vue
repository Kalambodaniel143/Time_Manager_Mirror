<template>
  <section class="card form-grid">
    <h2>Créer un compte</h2>
    <p class="small muted">Le compte est créé dans votre organisation. Transmettez vous-même le mot de passe.</p>
    <form v-if="open" class="form-grid" @submit.prevent="submit">
      <ProfileFields v-model="profile" />
      <label for="new-username">Nom d’utilisateur</label>
      <input id="new-username" v-model.trim="username" required autocomplete="off" />
      <label for="new-role">Rôle</label>
      <select id="new-role" v-model="role">
        <option v-for="r in roles" :key="r" :value="r">{{ ROLE_LABELS[r] ?? r }}</option>
      </select>
      <label for="new-user-password">Mot de passe provisoire <span class="muted small">({{ PASSWORD_RULE }})</span></label>
      <PasswordInput id="new-user-password" v-model="password" />
      <p v-if="message" class="notice-danger small" role="alert">{{ message }}</p>
      <div class="request-actions">
        <button type="button" class="btn-outline" @click="open = false">Annuler</button>
        <button type="submit" :disabled="busy">Créer</button>
      </div>
    </form>
    <template v-else>
      <p v-if="created" class="notice-ok small" role="status">Compte créé : <strong>{{ created }}</strong></p>
      <button type="button" class="btn-outline btn-block" @click="open = true">Nouveau compte</button>
    </template>
  </section>
</template>

<script>
import ProfileFields from '@/components/auth/ProfileFields.vue'
import PasswordInput from '@/components/auth/PasswordInput.vue'
import { api } from '@/services/source.js'
import { createUser } from '@/services/manageService.js'
import { PASSWORD_RULE, validPassword } from '@/ui/authErrors.js'
import { ROLE_LABELS } from '@/ui/format.js'

// POST /users : l'administration crée un compte dans son organisation (rôles lus avec GET /roles).
export default {
  name: 'NewUserForm',
  components: { ProfileFields, PasswordInput },
  emits: ['created'],
  data: () => ({
    open: false, busy: false, message: '', created: '', roles: ['employee', 'manager'], role: 'employee',
    username: '', password: '', profile: { first_name: '', last_name: '', email: '' }, ROLE_LABELS, PASSWORD_RULE,
  }),
  async created() {
    try { this.roles = (await api.getRoles()).map((r) => r.name) } catch { /* liste par défaut */ }
  },
  methods: {
    async submit() {
      if (!validPassword(this.password)) { this.message = `Mot de passe : ${PASSWORD_RULE}`; return }
      this.busy = true
      this.message = ''
      try {
        await createUser({ ...this.profile, username: this.username, password: this.password, role: this.role })
        this.created = `${this.profile.email} · ${ROLE_LABELS[this.role] ?? this.role}`
        Object.assign(this, { open: false, username: '', password: '', profile: { first_name: '', last_name: '', email: '' } })
        this.$emit('created')
      } catch (error) {
        this.message = error.message
      } finally {
        this.busy = false
      }
    },
  },
}
</script>
