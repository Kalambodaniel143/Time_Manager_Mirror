<template>
  <section class="card form-grid">
    <h2>Mot de passe</h2>
    <form v-if="open" class="form-grid" @submit.prevent="save">
      <label for="pw-current">Mot de passe actuel</label>
      <PasswordInput id="pw-current" v-model="current" autocomplete="current-password" />
      <label for="pw-new">Nouveau mot de passe <span class="muted small">({{ PASSWORD_RULE }})</span></label>
      <PasswordInput id="pw-new" v-model="next" />
      <label for="pw-confirm">Confirmer le nouveau mot de passe</label>
      <PasswordInput id="pw-confirm" v-model="confirm" />
      <p v-if="message" :class="ok ? 'notice-ok' : 'notice-danger'" class="small" role="status">{{ message }}</p>
      <div class="request-actions">
        <button type="button" class="btn-outline" @click="open = false">Annuler</button>
        <button type="submit" :disabled="busy">Enregistrer</button>
      </div>
    </form>
    <template v-else>
      <p v-if="ok" class="notice-ok small" role="status">{{ message }}</p>
      <button type="button" class="btn-quiet" @click="start">Changer mon mot de passe</button>
    </template>
  </section>
</template>

<script>
import PasswordInput from '@/components/auth/PasswordInput.vue'
import { changePassword } from '@/services/manageService.js'
import { PASSWORD_RULE, validPassword } from '@/ui/authErrors.js'

// PUT /users/:id { password, current_password } : changer son propre mot de passe.
export default {
  name: 'PasswordCard',
  components: { PasswordInput },
  data: () => ({ open: false, current: '', next: '', confirm: '', busy: false, message: '', ok: false, PASSWORD_RULE }),
  methods: {
    start() { Object.assign(this, { open: true, message: '', ok: false }) },
    async save() {
      this.ok = false
      if (!validPassword(this.next)) { this.message = `Nouveau mot de passe : ${PASSWORD_RULE}`; return }
      if (this.next !== this.confirm) { this.message = 'Les deux mots de passe sont différents.'; return }
      this.busy = true
      try {
        await changePassword(this.current, this.next)
        Object.assign(this, { ok: true, message: 'Mot de passe changé.', open: false })
      } catch (error) {
        this.message = error.message
      } finally {
        Object.assign(this, { current: '', next: '', confirm: '', busy: false })
      }
    },
  },
}
</script>
