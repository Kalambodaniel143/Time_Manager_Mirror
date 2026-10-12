<template>
  <section class="card form-grid">
    <h2>{{ team.name }}</h2>
    <label :for="`name-${team.id}`">Nom de l’équipe</label>
    <div class="request-actions">
      <input :id="`name-${team.id}`" v-model.trim="name" maxlength="100" />
      <button type="button" class="btn-outline" :disabled="busy || !name || name === team.name"
        @click="act(() => updateTeam(team.id, { name, manager_id: team.manager?.id ?? null }))">Renommer</button>
    </div>
    <label :for="`manager-${team.id}`">Responsable</label>
    <select :id="`manager-${team.id}`" :value="team.manager?.id ?? ''" :disabled="busy"
      @change="act(() => updateTeam(team.id, { name: team.name, manager_id: toId($event.target.value) }))">
      <option value="">Aucun</option>
      <option v-for="u in managers" :key="u.id" :value="u.id">{{ displayName(u) }}</option>
    </select>
    <p class="small muted">{{ team.members.length }} membre{{ team.members.length > 1 ? 's' : '' }}</p>
    <ul class="list flush">
      <li v-for="m in team.members" :key="m.id" class="row">
        <span>{{ displayName(m) }}</span>
        <button type="button" class="btn-quiet" :disabled="busy" :aria-label="`Retirer ${displayName(m)}`"
          @click="act(() => removeMember(team.id, m.id))">Retirer</button>
      </li>
    </ul>
    <label :for="`add-${team.id}`">Ajouter un agent</label>
    <select :id="`add-${team.id}`" :disabled="busy || !candidates.length" @change="add($event.target)">
      <option value="">Choisir…</option>
      <option v-for="u in candidates" :key="u.id" :value="u.id">{{ displayName(u) }}</option>
    </select>
    <p v-if="message" class="notice-danger small" role="alert">{{ message }}</p>
    <button type="button" class="btn-danger" :disabled="busy" @click="remove">Supprimer l’équipe</button>
  </section>
</template>

<script>
import { addMember, deleteTeam, removeMember, updateTeam } from '@/services/manageService.js'
import { confirmAction } from '@/native/device.js'
import { displayName } from '@/ui/format.js'

// Une équipe : changer de responsable, ajouter / retirer des membres, supprimer.
export default {
  name: 'TeamEditor',
  props: { team: { type: Object, required: true }, users: { type: Array, required: true } },
  emits: ['changed'],
  data() { return { busy: false, message: '', name: this.team.name } },
  computed: {
    managers() { return this.users.filter((u) => u.role !== 'employee') },
    candidates() { return this.users.filter((u) => !this.team.members.some((m) => m.id === u.id)) },
  },
  methods: {
    updateTeam, removeMember, displayName,
    toId: (value) => (value === '' ? null : Number(value)),
    async act(task) {
      this.busy = true
      this.message = ''
      try { await task(); this.$emit('changed') } catch (error) { this.message = error.message }
      finally { this.busy = false }
    },
    add(select) {
      if (select.value) this.act(() => addMember(this.team.id, Number(select.value)))
      select.value = ''
    },
    async remove() {
      if (await confirmAction(`Supprimer l’équipe « ${this.team.name} » ? Les comptes sont conservés.`)) {
        this.act(() => deleteTeam(this.team.id))
      }
    },
  },
}
</script>
