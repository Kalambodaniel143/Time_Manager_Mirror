<template>
  <section class="card form-grid">
    <p class="row"><strong>{{ title }}</strong>
      <span class="badge" :class="draft ? 'badge-warn' : 'badge-ok'">{{ draft ? $t('Brouillon à publier') : $t('Publié') }}</span></p>
    <p v-if="plan.published_at" class="small muted">{{ $t('Dernière publication {0}', [ago(plan.published_at)]) }}</p>
    <p v-if="hidden" class="small muted">{{ hidden > 1 ? $t('{0} créneaux de ce planning sont hors de la période affichée.', [hidden]) : $t('1 créneau de ce planning est hors de la période affichée.') }}</p>
    <p v-if="!shifts.length" class="small muted">{{ $t('Aucun créneau pour l’instant.') }}</p>
    <ul class="list flush scroll-box">
      <li v-for="s in shifts" :key="s.id">
        <div class="row">
          <span>{{ when(s) }}<br><span class="small muted">{{ personName(s, plan.members) }} · {{ SHIFT_KINDS[s.kind] ?? s.kind }}<template v-if="s.place"> · {{ s.place }}</template></span></span>
          <span v-if="plan.can_manage && isFuture(s)" class="shift-actions">
            <button type="button" class="icon-btn round" :disabled="busy" :aria-label="$t('Modifier le créneau')" @click="editing = editing === s.id ? null : s.id"><Pencil :size="16" /></button>
            <button type="button" class="icon-btn round" :disabled="busy" :aria-label="$t('Supprimer le créneau')" @click="$emit('remove-shift', s)"><Trash2 :size="16" /></button>
          </span>
        </div>
        <ShiftForm v-if="editing === s.id" class="inline-form" :members="plan.members ?? []" :initial="s" :busy="busy"
          @save="$emit('save-shift', { id: s.id, shift: $event }); editing = null" @cancel="editing = null" />
      </li>
    </ul>
    <details v-if="plan.can_manage" class="fold">
      <summary>{{ $t('Ajouter un créneau') }}</summary>
      <ShiftForm :members="plan.members ?? []" :busy="busy" @save="$emit('save-shift', { shift: $event })" />
    </details>
    <details v-if="plan.can_manage" class="fold">
      <summary>{{ $t('Modifier la période') }}</summary>
      <PeriodForm :start="plan.start" :end="planEnd(plan)" :label="$t('Enregistrer la période')" :busy="busy" @save="$emit('edit-period', $event)" />
    </details>
    <button v-if="plan.can_publish && draft" type="button" :disabled="busy" @click="$emit('publish')">{{ $t('Publier ce planning') }}</button>
    <p v-else-if="draft && !plan.can_publish" class="small muted">{{ $t('La publication est réservée aux responsables qui en ont le droit.') }}</p>
    <button v-if="plan.can_manage" type="button" class="btn-quiet danger-text" :disabled="busy" @click="$emit('remove')">{{ $t('Supprimer ce planning') }}</button>
  </section>
</template>

<script>
import { Pencil, Trash2 } from 'lucide-vue-next'
import ShiftForm from './ShiftForm.vue'
import PeriodForm from './PeriodForm.vue'
import { isFuture, planEnd, shiftsOf } from '@/ui/plans.js'
import { personName } from '@/ui/people.js'
import { SHIFT_KINDS } from '@/ui/statusLabels.js'
import { ago, dayMonth, hhmm, shortDay } from '@/ui/format.js'
import { localDay } from '@/ui/dates.js'

// Un planning d'équipe : créneaux (ajout, modification, suppression), période, publication, suppression.
// Les droits viennent du serveur (can_manage, can_publish), qui revérifie chaque action.
export default {
  name: 'PlanCard',
  components: { Pencil, Trash2, ShiftForm, PeriodForm },
  props: { plan: { type: Object, required: true }, range: { type: Object, default: null }, busy: Boolean },
  emits: ['save-shift', 'remove-shift', 'edit-period', 'publish', 'remove'],
  data: () => ({ editing: null, SHIFT_KINDS }),
  computed: {
    all() { return shiftsOf([this.plan]).sort((a, b) => a.start.localeCompare(b.start)) },
    // Créneaux de la période affichée (le planning peut déborder de la période choisie).
    shifts() { return this.range ? this.all.filter((s) => localDay(s.start) >= this.range.from && localDay(s.start) <= this.range.to) : this.all },
    hidden() { return this.all.length - this.shifts.length },
    draft() { return this.plan.revision !== this.plan.published_revision },
    title() { return `${dayMonth(`${this.plan.start}T12:00`)} – ${dayMonth(`${planEnd(this.plan)}T12:00`)}` },
  },
  methods: {
    ago, isFuture, personName, planEnd,
    when: (s) => `${shortDay(s.start)} · ${hhmm(s.start)}–${hhmm(s.end)}`,
  },
}
</script>
