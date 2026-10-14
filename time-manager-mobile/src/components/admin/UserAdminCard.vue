<template>
  <section class="card form-grid">
    <h2>{{ $t('Administration du compte') }}</h2>
    <dl v-if="user.birth_date || user.gender" class="details small">
      <div><dt>{{ $t('Genre') }}</dt><dd>{{ GENDERS[user.gender] ?? '—' }}</dd></div>
      <div><dt>{{ $t('Naissance') }}</dt><dd>{{ user.birth_date ?? '—' }} {{ user.birth_place ? $t('à {0}', [user.birth_place]) : '' }}</dd></div>
    </dl>
    <label for="role">{{ $t('Rôle') }}</label>
    <select id="role" :value="user.role" :disabled="busy" @change="changeRole($event.target)">
      <option v-for="r in roles" :key="r" :value="r">{{ ROLE_LABELS[r] ?? r }}</option>
    </select>
    <label for="reset-password">{{ $t('Nouveau mot de passe') }} <span class="muted small">{{ $t('(réinitialisation, {0})', [PASSWORD_RULE]) }}</span></label>
    <div class="request-actions">
      <input id="reset-password" v-model="password" type="text" autocomplete="off" />
      <button type="button" class="btn-outline" :disabled="busy || !valid" @click="reset">{{ $t('Réinitialiser') }}</button>
    </div>
    <p v-if="message" class="small" :class="ok ? 'notice-ok' : 'notice-danger'" role="status">{{ message }}</p>
    <button type="button" class="btn-danger btn-block" :disabled="busy" @click="remove">{{ $t('Supprimer ce compte') }}</button>
  </section>
</template>

<script>
import { t } from '@/i18n/index.js'
import { api } from '@/services/source.js'
import { changeRole, deleteUser, resetPassword } from '@/services/manageService.js'
import { ROLE_LABELS, displayName } from '@/ui/format.js'
import { PASSWORD_RULE, validPassword } from '@/ui/authErrors.js'
import { confirmAction } from '@/native/device.js'

const GENDERS = { female: t('Femme'), male: t('Homme'), non_binary: t('Non binaire'), unspecified: t('Non précisé') }

// Administration : informations personnelles, rôle, réinitialisation du mot de passe, suppression.
export default {
  name: 'UserAdminCard',
  props: { user: { type: Object, required: true } },
  emits: ['changed', 'deleted'],
  data: () => ({ roles: Object.keys(ROLE_LABELS), password: '', busy: false, message: '', ok: false, ROLE_LABELS, GENDERS, PASSWORD_RULE }),
  computed: { valid() { return validPassword(this.password) } },
  async created() {
    try { this.roles = (await api.getRoles()).map((r) => r.name) } catch { /* liste par défaut */ }
  },
  methods: {
    async act(task, success) {
      this.busy = true
      try { await task(); this.ok = true; this.message = success; return true }
      catch (error) { this.ok = false; this.message = error.message; return false }
      finally { this.busy = false }
    },
    async changeRole(select) {
      const role = select.value
      if (await this.act(() => changeRole(this.user.id, role), t('Rôle changé : {0}.', [ROLE_LABELS[role]]))) this.$emit('changed')
      else select.value = this.user.role // refusé : on remet l'ancien rôle
    },
    async reset() {
      const password = this.password
      if (await this.act(() => resetPassword(this.user.id, password), t('Mot de passe réinitialisé : transmettez « {0} ».', [password]))) this.password = ''
    },
    async remove() {
      if (!await confirmAction(t('Supprimer définitivement le compte de {0} et ses heures ?', [displayName(this.user)]))) return
      if (await this.act(() => deleteUser(this.user.id), t('Compte supprimé.'))) this.$emit('deleted')
    },
  },
}
</script>
