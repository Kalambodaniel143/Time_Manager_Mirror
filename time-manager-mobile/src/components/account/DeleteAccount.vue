<template>
  <section class="card form-grid">
    <h2>{{ $t('Supprimer mon compte') }}</h2>
    <p class="small muted">{{ $t('Supprime votre compte, vos pointages et vos heures. Action définitive.') }}</p>
    <template v-if="open">
      <label for="delete-password">{{ $t('Votre mot de passe actuel') }}</label>
      <PasswordInput id="delete-password" v-model="password" autocomplete="current-password" />
      <p v-if="message" class="notice-danger small" role="alert">{{ message }}</p>
      <div class="request-actions">
        <button type="button" class="btn-outline" :disabled="busy" @click="open = false">{{ $t('Annuler') }}</button>
        <button type="button" class="btn-danger" :disabled="busy || !password" @click="remove">{{ $t('Supprimer') }}</button>
      </div>
    </template>
    <button v-else type="button" class="btn-danger btn-block" @click="open = true">{{ $t('Supprimer mon compte') }}</button>
  </section>
</template>

<script>
import { t } from '@/i18n/index.js'
import PasswordInput from '@/components/auth/PasswordInput.vue'
import { deleteOwnAccount } from '@/services/manageService.js'
import { confirmAction } from '@/native/device.js'

// DELETE /users/:id avec current_password : le serveur exige le mot de passe pour supprimer son propre compte.
export default {
  name: 'DeleteAccount',
  components: { PasswordInput },
  data: () => ({ open: false, password: '', busy: false, message: '' }),
  methods: {
    async remove() {
      if (!await confirmAction(t('Supprimer définitivement votre compte et toutes vos heures ?'), 'Supprimer')) return
      this.busy = true
      this.message = ''
      try { await deleteOwnAccount(this.password) } catch (error) { this.message = error.message } finally { this.password = ''; this.busy = false }
    },
  },
}
</script>
