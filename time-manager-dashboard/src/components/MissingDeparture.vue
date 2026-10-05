<template>
  <!-- Le même formulaire est utilisable dans l'accueil et dans une ligne du tableau. -->
  <component :is="tableRow ? 'tr' : 'section'" v-if="visible">
    <component :is="tableRow ? 'td' : 'div'" :colspan="tableRow ? 5 : undefined">
      <div class="missing-departure">
        <AlertBanner v-if="missing" title="Départ à vérifier" :text="description">
          <button v-if="!editing" class="btn btn-outline" type="button" :disabled="loading || saving" @click="editing = true">
            Compléter
          </button>
        </AlertBanner>

        <form v-if="missing && editing" class="completion-form" novalidate @submit.prevent="submit">
          <label class="field-label" :for="inputId">Date et heure réelles du départ</label>
          <input :id="inputId" v-model="finish" class="input" type="datetime-local" step="1" :min="minimum" :max="maximum" :disabled="saving || needsRefresh" required />
          <p class="hint">Heure locale. Le départ doit suivre le dernier pointage et dater de moins de 7 jours.</p>
          <div class="actions">
            <button class="btn btn-primary" type="submit" :disabled="saving || loading || needsRefresh">{{ saving ? 'Enregistrement…' : 'Confirmer' }}</button>
            <button class="btn btn-quiet" type="button" :disabled="saving" @click="editing = false">Annuler</button>
          </div>
        </form>

        <p v-if="error" class="field-error" role="alert">{{ error }}</p>
        <button v-if="needsRefresh" class="btn btn-outline" type="button" :disabled="loading || saving" @click="refresh">
          {{ loading ? 'Actualisation…' : 'Actualiser les pointages' }}
        </button>
      </div>
    </component>
  </component>
</template>

<script>
import AlertBanner from './ui/AlertBanner.vue'
import { completeDeparture, getClocks } from '../services/clockService'
import { formatClockDate } from '../utils/clockDate'
import { clockDate, CORRECTION_WINDOW, departureError, findMissingDeparture, localDateInput } from '../utils/missingDeparture'
import { addDays } from '../utils/hours'
import { toDateInput } from '../utils/date'

export default {
  name: 'MissingDeparture',
  components: { AlertBanner },
  props: {
    userId: { type: [Number, String], required: true },
    now: { type: Date, required: true },
    tableRow: { type: Boolean, default: false },
    weekStart: { type: Date, default: null },
  },
  emits: ['completed', 'detected', 'refreshed'],
  data() {
    return { clocks: [], editing: false, finish: '', loading: false, saving: false, error: '', needsRefresh: false, requestVersion: 0 }
  },
  computed: {
    missing() {
      return findMissingDeparture(this.clocks, this.now)
    },
    visible() {
      if (this.error) return true
      if (!this.missing) return false
      if (!this.weekStart) return true
      const day = formatClockDate(this.missing.arrival.time).slice(0, 10)
      return day >= toDateInput(this.weekStart) && day < toDateInput(addDays(this.weekStart, 7))
    },
    description() {
      const date = clockDate(this.missing.arrival.time).toLocaleString('fr-FR', {
        weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit', second: '2-digit',
      })
      return `Aucun départ enregistré pour le service commencé ${date}. Si vous avez terminé, complétez votre départ.`
    },
    inputId() {
      return `departure-${this.userId}-${this.tableRow ? 'table' : 'home'}`
    },
    minimum() {
      const last = clockDate(this.missing.last.time).getTime() + (this.missing.last.status ? 1000 : 0)
      return localDateInput(new Date(Math.ceil(Math.max(last, this.now.getTime() - CORRECTION_WINDOW) / 1000) * 1000))
    },
    maximum() {
      return localDateInput(this.now)
    },
  },
  watch: {
    userId: { immediate: true, handler() { this.refresh() } },
    weekStart() { this.refresh() },
    missing: { immediate: true, handler(value) { this.$emit('detected', value) } },
  },
  beforeUnmount() {
    this.requestVersion += 1
  },
  methods: {
    async refresh() {
      const userId = this.userId
      const recovering = this.needsRefresh
      const version = ++this.requestVersion
      this.loading = true
      this.clocks = []
      this.error = ''
      this.editing = false
      this.finish = ''
      this.needsRefresh = false
      try {
        const clocks = await getClocks(userId)
        if (version !== this.requestVersion || userId !== this.userId) return
        if (!Array.isArray(clocks)) throw new Error('Réponse invalide')
        findMissingDeparture(clocks, this.now)
        this.clocks = clocks
        // Après une réponse perdue, remettre aussi le compteur et les totaux à jour.
        if (recovering) this.$emit('refreshed')
      } catch {
        if (version !== this.requestVersion || userId !== this.userId) return
        this.error = 'Impossible de vérifier les départs. Actualisez les pointages.'
        this.needsRefresh = true
      } finally {
        if (version === this.requestVersion) this.loading = false
      }
    },
    async submit() {
      if (this.loading || this.saving || this.needsRefresh || !this.missing) return
      // Vérifier avant d'envoyer, puis le serveur vérifie à nouveau.
      this.error = departureError(this.finish, this.missing.last, new Date())
      if (this.error) return
      const userId = this.userId
      const version = this.requestVersion
      this.saving = true
      try {
        await completeDeparture(userId, this.missing.last.id, formatClockDate(new Date(this.finish)))
        if (version !== this.requestVersion || userId !== this.userId) return
        this.$emit('completed')
        await this.refresh()
      } catch (error) {
        if (version !== this.requestVersion || userId !== this.userId) return
        const detail = error.payload?.errors?.time?.join(' ')
        this.error = detail || 'Départ non confirmé. Actualisez les pointages avant de réessayer.'
        // Une réponse perdue peut cacher un départ déjà enregistré : ne pas renvoyer à l'aveugle.
        this.needsRefresh = true
      } finally {
        this.saving = false
      }
    },
  },
}
</script>

<style scoped>
.missing-departure { display: grid; gap: 12px; }
.completion-form { display: grid; gap: 10px; padding: 18px; border: 1px solid var(--border); border-radius: var(--radius); background: var(--surface); }
.input { min-width: 0; width: 100%; }
.actions { display: flex; flex-wrap: wrap; gap: 8px; }
.hint { font-size: 13px; color: var(--text-muted); }
</style>
