<template>
  <section class="card form-grid">
    <h2>{{ $t('Droits des responsables') }}</h2>
    <p class="small muted">{{ $t('Par équipe : ce que son responsable peut faire. L’administration garde tous ses droits.') }}</p>
    <p v-if="message" class="notice-danger small" role="alert">{{ message }}</p>
    <div class="scroll-box">
      <article v-for="t in teams" :key="t.id" class="form-grid team-rights">
        <strong>{{ t.name }}</strong>
        <p v-if="!rights[t.id]" class="small muted">{{ $t('Chargement…') }}</p>
        <label v-for="(label, key) in LABELS" v-else :key="key" class="choice">
          <input type="checkbox" :checked="rights[t.id][key]" :disabled="busy" @change="toggle(t, key, $event.target.checked)" /> {{ label }}
        </label>
      </article>
    </div>
  </section>
</template>

<script>
import { t } from '@/i18n/index.js'
import { act, api } from '@/services/workforce.js'

const LABELS = { validate: t('Valider les semaines'), correct: t('Décider des corrections'), publish: t('Publier le planning') }
const flags = (data) => data?.permissions ?? data ?? {}

// Droits fins par équipe (GET/PATCH /teams/:id/permissions).
export default {
  name: 'TeamPermissions',
  props: { teams: { type: Array, required: true } },
  data: () => ({ rights: {}, busy: false, message: '', LABELS }),
  async created() {
    await Promise.all(this.teams.map(async (t) => {
      try { this.rights[t.id] = flags(await act(() => api.getTeamPermissions(t.id))) } catch (e) { this.message = e.message }
    }))
  },
  methods: {
    async toggle(team, key, value) {
      this.busy = true
      try { this.rights[team.id] = flags(await act(() => api.saveTeamPermissions(team.id, { ...this.rights[team.id], [key]: value }))) }
      catch (e) { this.message = e.message } finally { this.busy = false }
    },
  },
}
</script>
