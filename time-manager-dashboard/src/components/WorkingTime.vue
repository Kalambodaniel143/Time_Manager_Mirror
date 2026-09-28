<template>
  <Teleport to="body">
    <div v-if="open" class="overlay" @click.self="close">
      <form class="dialog card" novalidate @submit.prevent="submit">
        <header class="dialog-header">
          <div>
            <p class="eyebrow">{{ isEditing ? `Période n° ${form.id}` : 'Nouvelle période' }}</p>
            <h3 class="card-title">{{ title }}</h3>
          </div>
          <button class="btn btn-quiet btn-icon btn-sm" type="button" aria-label="Fermer" @click="close">
            <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M4 4l8 8M12 4l-8 8" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" /></svg>
          </button>
        </header>

        <div class="dialog-body">
          <div v-if="!isEditing" class="presets">
            <span class="field-label">Raccourcis</span>
            <div class="preset-list">
              <button
                v-for="preset in presets"
                :key="preset.label"
                class="chip"
                :class="{ 'is-active': isPresetActive(preset) }"
                type="button"
                @click="applyPreset(preset)"
              >
                {{ preset.label }} <span class="preset-hours num">{{ preset.hint }}</span>
              </button>
            </div>
          </div>

          <div class="field">
            <label class="field-label" for="wt-day">Jour</label>
            <input
              id="wt-day"
              v-model="fields.day"
              class="input"
              :class="{ 'has-error': showErrors && errors.day }"
              type="date"
            />
            <span v-if="showErrors && errors.day" class="field-error">{{ errors.day }}</span>
          </div>

          <div class="time-row">
            <div class="field">
              <label class="field-label" for="wt-start">Début</label>
              <input
                id="wt-start"
                v-model="fields.startTime"
                class="input num"
                :class="{ 'has-error': showErrors && errors.start }"
                type="time"
                step="1"
              />
            </div>
            <span class="time-arrow" aria-hidden="true">→</span>
            <div class="field">
              <label class="field-label" for="wt-end">Fin</label>
              <input
                id="wt-end"
                v-model="fields.endTime"
                class="input num"
                :class="{ 'has-error': showErrors && errors.end }"
                type="time"
                step="1"
              />
            </div>
          </div>
          <span v-if="showErrors && (errors.start || errors.end)" class="field-error time-error">
            {{ errors.start || errors.end }}
          </span>

          <label class="switch-row">
            <input v-model="fields.nextDay" class="switch-input" type="checkbox" />
            <span class="switch" aria-hidden="true"></span>
            <span>
              Se termine le lendemain
              <span class="switch-hint">pour les horaires de nuit</span>
            </span>
          </label>

          <p v-if="suggestNextDay" class="suggestion">
            L'heure de fin est avant l'heure de début.
            <button class="link-btn" type="button" @click="fields.nextDay = true">
              Terminer le lendemain ?
            </button>
          </p>

          <div class="summary" :class="{ muted: durationHours <= 0 }">
            <div>
              <p class="eyebrow">Durée</p>
              <p class="summary-value serif num">{{ durationLabel }}</p>
            </div>
            <div class="summary-range num" title="Format envoyé à l'API">
              <span>{{ form.start || '—' }}</span>
              <span>{{ form.end || '—' }}</span>
            </div>
          </div>

          <p v-if="submitError" class="form-error">{{ submitError }}</p>
        </div>

        <footer class="dialog-footer">
          <button
            v-if="isEditing"
            class="btn btn-danger"
            :class="{ 'is-armed': deleteArmed }"
            type="button"
            :disabled="saving"
            @click="deleteArmed ? deleteWorkingTime() : armDelete()"
          >
            {{ deleteArmed ? 'Vraiment supprimer ?' : 'Supprimer' }}
          </button>
          <span class="spacer"></span>
          <button class="btn btn-ghost" type="button" :disabled="saving" @click="close">Annuler</button>
          <button class="btn btn-primary" type="submit" :disabled="saving">
            {{ saving ? 'Enregistrement…' : isEditing ? 'Enregistrer' : 'Ajouter la période' }}
          </button>
        </footer>
      </form>
    </div>
  </Teleport>
</template>

<script>
import * as workingTimeService from '../services/workingTimeService'
import {
  combineDateTime,
  durationInHours,
  formatDuration,
  formatLongDate,
  isSameDay,
  toDateInput,
  toTimeInput,
  todayInput,
} from '../utils/date'
import { notify } from '../utils/toast'

const PRESETS = [
  { label: 'Matinée', hint: '8h–12h', start: '08:00:00', end: '12:00:00' },
  { label: 'Journée', hint: '9h–17h', start: '09:00:00', end: '17:00:00' },
  { label: 'Après-midi', hint: '13h30–18h', start: '13:30:00', end: '18:00:00' },
  { label: 'Longue journée', hint: '8h–19h', start: '08:00:00', end: '19:00:00' },
]

export default {
  name: 'WorkingTime',

  props: {
    userId: { type: [Number, String], required: true },
    workingTime: { type: Object, default: null },
    workingTimeId: { type: [Number, String], default: null },
    open: { type: Boolean, default: false },
  },

  emits: ['close', 'saved', 'deleted'],

  data() {
    return {
      presets: PRESETS,
      form: { id: null, start: '', end: '' },
      fields: { day: '', startTime: '', endTime: '', nextDay: false },
      showErrors: false,
      saving: false,
      submitError: '',
      deleteArmed: false,
      disarmTimer: null,
    }
  },

  computed: {
    isEditing() {
      return this.form.id !== null
    },

    title() {
      if (!this.isEditing) return 'Quand avez-vous travaillé ?'

      const label = formatLongDate(this.form.start)
      return label ? label.charAt(0).toUpperCase() + label.slice(1) : 'Modifier la période'
    },

    durationHours() {
      return durationInHours(this.form.start, this.form.end)
    },

    durationLabel() {
      return this.durationHours > 0 ? formatDuration(this.durationHours) : '—'
    },

    suggestNextDay() {
      const { startTime, endTime, nextDay } = this.fields
      return Boolean(startTime && endTime && !nextDay && endTime <= startTime)
    },

    errors() {
      const errors = {}

      if (!this.fields.day) errors.day = 'Choisissez un jour.'
      if (!this.fields.startTime) errors.start = 'Indiquez une heure de début.'
      else if (!this.fields.endTime) errors.end = 'Indiquez une heure de fin.'
      else if (this.durationHours <= 0) errors.end = 'La fin doit être après le début.'

      return errors
    },
  },

  watch: {
    fields: {
      deep: true,
      handler(value) {
        this.form.start = combineDateTime(value.day, value.startTime)
        this.form.end = combineDateTime(value.day, value.endTime, value.nextDay ? 1 : 0)
      },
    },

    workingTime: {
      immediate: true,
      handler(value) {
        this.reset(value)
      },
    },

    workingTimeId: {
      immediate: true,
      handler(value) {
        if (value) this.loadById(value)
      },
    },

    open: {
      immediate: true,
      handler(value) {
        if (value && !this.workingTimeId) this.reset(this.workingTime)
        this.toggleKeyListener(value)
      },
    },
  },

  beforeUnmount() {
    this.toggleKeyListener(false)
    clearTimeout(this.disarmTimer)
  },

  methods: {
    async loadById(id) {
      try {
        const found = await workingTimeService.getWorkingTime(this.userId, id)
        if (found) this.reset(found)
        else this.submitError = 'Cette période est introuvable.'
      } catch (error) {
        this.submitError = error.message
      }
    },

    reset(source) {
      this.submitError = ''
      this.saving = false
      this.showErrors = false
      this.deleteArmed = false

      if (source) {
        this.form = { id: source.id, start: source.start, end: source.end }
        this.fields = {
          day: toDateInput(source.start),
          startTime: toTimeInput(source.start),
          endTime: toTimeInput(source.end),
          nextDay: !isSameDay(source.start, source.end),
        }
      } else {
        this.form = { id: null, start: '', end: '' }
        this.fields = { day: todayInput(), startTime: '09:00:00', endTime: '17:00:00', nextDay: false }
      }
    },

    isPresetActive(preset) {
      return this.fields.startTime === preset.start && this.fields.endTime === preset.end
    },

    applyPreset(preset) {
      this.fields = { ...this.fields, startTime: preset.start, endTime: preset.end, nextDay: false }
    },

    close() {
      if (!this.saving) this.$emit('close')
    },

    submit() {
      this.showErrors = true
      if (Object.keys(this.errors).length > 0) return

      return this.isEditing ? this.updateWorkingTime() : this.createWorkingTime()
    },

    async createWorkingTime() {
      this.saving = true
      this.submitError = ''

      try {
        const created = await workingTimeService.createWorkingTime(this.userId, {
          start: this.form.start,
          end: this.form.end,
        })

        notify(`Période ajoutée · ${formatDuration(this.durationHours)} de travail.`)
        this.$emit('saved', created)
        this.$emit('close')
      } catch (error) {
        this.submitError = error.message
      } finally {
        this.saving = false
      }
    },

    async updateWorkingTime() {
      this.saving = true
      this.submitError = ''

      try {
        const updated = await workingTimeService.updateWorkingTime(this.form.id, {
          start: this.form.start,
          end: this.form.end,
        })

        notify('Période mise à jour.')
        this.$emit('saved', updated)
        this.$emit('close')
      } catch (error) {
        this.submitError = error.message
      } finally {
        this.saving = false
      }
    },

    async deleteWorkingTime() {
      this.saving = true
      this.submitError = ''
      clearTimeout(this.disarmTimer)

      try {
        await workingTimeService.deleteWorkingTime(this.form.id)
        notify('Période supprimée.')
        this.$emit('deleted', this.form.id)
        this.$emit('close')
      } catch (error) {
        this.submitError = error.message
      } finally {
        this.saving = false
        this.deleteArmed = false
      }
    },

    armDelete() {
      this.deleteArmed = true
      clearTimeout(this.disarmTimer)
      this.disarmTimer = setTimeout(() => {
        this.deleteArmed = false
      }, 4000)
    },

    toggleKeyListener(active) {
      document.removeEventListener('keydown', this.onKeydown)
      if (active) document.addEventListener('keydown', this.onKeydown)
    },

    onKeydown(event) {
      if (event.key === 'Escape') this.close()
    },
  },
}
</script>

<style scoped>
.presets {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.preset-list {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.preset-hours {
  color: var(--text-subtle);
  font-weight: 400;
}

.chip.is-active .preset-hours {
  color: inherit;
  opacity: 0.75;
}

.time-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  align-items: end;
  gap: 10px;
}

.time-row .input {
  min-width: 0;
}

.time-arrow {
  padding-bottom: 10px;
  color: var(--text-subtle);
  font-size: 16px;
}

.time-error {
  margin-top: -10px;
}

.switch-row {
  display: flex;
  align-items: center;
  gap: 12px;
  font-size: 13.5px;
  cursor: pointer;
  user-select: none;
}

.switch-input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.switch {
  position: relative;
  flex-shrink: 0;
  width: 36px;
  height: 21px;
  background: var(--border-strong);
  border-radius: 999px;
  transition: background-color 0.18s ease;
}

.switch::after {
  content: '';
  position: absolute;
  top: 2.5px;
  left: 2.5px;
  width: 16px;
  height: 16px;
  background: #fff;
  border-radius: 50%;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.25);
  transition: transform 0.18s ease;
}

.switch-input:checked + .switch {
  background: var(--accent);
}

.switch-input:checked + .switch::after {
  transform: translateX(15px);
}

.switch-input:focus-visible + .switch {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}

.switch-hint {
  display: block;
  font-size: 12px;
  color: var(--text-subtle);
}

.suggestion {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 4px 8px;
  margin-top: -6px;
  padding: 10px 12px;
  background: var(--warning-soft);
  border-radius: var(--radius-sm);
  font-size: 13px;
  color: var(--warning);
}

.link-btn {
  padding: 0;
  background: none;
  border: none;
  font-weight: 600;
  color: inherit;
  text-decoration: underline;
  text-underline-offset: 3px;
}

.summary {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 18px;
  background: var(--accent-soft);
  border-radius: var(--radius);
  transition: background-color 0.2s ease;
}

.summary.muted {
  background: var(--surface-muted);
}

.summary-value {
  font-size: 34px;
  line-height: 1.1;
  color: var(--accent);
}

.summary.muted .summary-value {
  color: var(--text-subtle);
}

.summary-range {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  font-family: var(--mono);
  font-size: 11.5px;
  line-height: 1.6;
  color: var(--text-muted);
}

.form-error {
  padding: 11px 14px;
  background: var(--danger-soft);
  border-radius: var(--radius-sm);
  font-size: 13px;
  color: var(--danger);
}
</style>
