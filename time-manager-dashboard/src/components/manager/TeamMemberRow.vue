<template>
  <li class="member" :class="{ 'is-selected': selected }">
    <input
      class="check"
      type="checkbox"
      :checked="selected"
      :disabled="!canValidate || row.validated || row.departureInWeek || !!row.clockError"
      :aria-label="$t(`Sélectionner ${row.name}`)"
      @change="$emit('toggle', row.username)"
    />
    <div class="who">
      <p class="name">{{ row.name }}</p>
      <p class="job">{{ row.job }}</p>
    </div>
    <div class="tags">
      <HourTag v-for="tag in tags" :key="tag.kind" :kind="tag.kind" :hours="tag.hours" />
    </div>
    <p class="total serif num">{{ total }}</p>
    <p class="status">
      <span v-if="row.clockError" class="pill pill-todo"><AppIcon name="alert" />{{ $t("Pointages non vérifiés") }}</span>
      <span v-else-if="row.departureInWeek" class="pill pill-todo"><AppIcon name="clock" />{{ $t("Départ à compléter") }}</span>
      <span v-else-if="row.frequencyExceeded" class="pill pill-warn"><AppIcon name="alert" />{{ $t("Fréquence de nuits à examiner") }}</span>
      <span v-else-if="row.nightRun > maxNights" class="pill pill-danger"><AppIcon name="alert" />{{ row.nightRun }} {{ $t("nuits d’affilée") }}</span>
      <span v-else-if="row.validated" class="pill pill-ok"><AppIcon name="check" />{{ $t(row.sheetStatus === 'closed' ? 'Clôturée' : 'Validée') }}</span>
      <span v-else-if="canValidate" class="pill pill-todo"><AppIcon name="clock" />{{ $t("À valider") }}</span>
      <span v-else class="pill pill-ok">{{ $t(row.buckets.total > 0 ? 'Périodes enregistrées' : 'Aucune période') }}</span>
    </p>
    <div v-if="canTransition" class="sheet-actions"><button class="btn btn-outline btn-sm" @click="action = row.sheetStatus === 'validated' ? 'close' : 'reopen'; reason = ''">{{ $t(row.sheetStatus === 'validated' ? 'Clôturer' : 'Rouvrir') }}</button></div>
    <p v-if="canValidate" class="note"><AppIcon name="message" />{{ row.note || $t('Aucune note partagée') }}</p>
    <ModalDialog v-if="action" :title="$t(action === 'close' ? 'Clôturer la semaine' : 'Rouvrir la semaine')" :id="`sheet-${row.user.id}`" @close="action = ''"><label class="field"><span class="field-label">{{ $t("Motif") }}</span><textarea v-model.trim="reason" class="input" maxlength="500" /></label><button class="btn btn-primary" :disabled="!reason" @click="transition">{{ $t("Confirmer") }}</button></ModalDialog>
    <RouterLink v-if="row.user" class="btn btn-outline btn-sm view-link" :to="{ name: 'workingTimes', params: { userID: row.user.id } }">{{ $t("Voir la fiche") }}</RouterLink>
  </li>
</template>

<script>
import { RouterLink } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import ModalDialog from '../ui/ModalDialog.vue'
import { auth } from '../../stores/auth'
import HourTag from '../ui/HourTag.vue'
import { formatHours } from '../../utils/hours'

const ORDER = ['night', 'day', 'oncall', 'sup']

export default {
  name: 'TeamMemberRow',

  components: { ModalDialog, AppIcon, HourTag, RouterLink },

  props: {
    row: { type: Object, required: true },
    selected: { type: Boolean, default: false },
    maxNights: { type: Number, required: true },
    canValidate: { type: Boolean, default: true },
  },

  emits: ['toggle', 'transition'],
  data() { return { action: '', reason: '' } },
  methods: { transition() { this.$emit('transition', { row: this.row, action: this.action, reason: this.reason }); this.action = '' } },

  computed: {
    canTransition() { return this.canValidate && this.row.user?.id !== auth.user?.id && ['validated', 'closed'].includes(this.row.sheetStatus) },
    tags() {
      const first = this.row.buckets.night > this.row.buckets.day ? ORDER : ['day', 'night', 'oncall', 'sup']
      return first.filter((kind) => this.row.buckets[kind] > 0).map((kind) => ({ kind, hours: this.row.buckets[kind] }))
    },

    total() {
      return formatHours(this.row.buckets.total)
    },
  },
}
</script>

<style scoped>
.member {
  display: grid;
  grid-template-columns: 22px minmax(150px, 280px) minmax(0, 1fr) 110px 170px;
  align-items: center;
  gap: 8px 26px;
  padding: 14px 18px 14px 18px;
  border-top: 1px solid var(--border);
}

.member.is-selected {
  background: var(--brand-soft);
}

.check {
  width: 22px;
  height: 22px;
  accent-color: var(--brand);
}

.name {
  font-size: 16px;
  font-weight: 700;
}

.job {
  font-size: 14px;
  color: var(--text-muted);
}

.tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.total {
  font-size: 30px;
  text-align: right;
}

.note {
  grid-column: 2 / -1;
  display: flex;
  align-items: center;
  gap: 10px;
  margin-top: -4px;
  font-size: 14px;
  color: var(--text-muted);
}

.note svg {
  width: 16px;
  height: 16px;
}

@media (max-width: 1100px) {
  .member {
    grid-template-columns: 22px minmax(0, 1fr) auto;
  }

  .tags,
  .status,
  .note {
    grid-column: 2 / -1;
  }

  .total {
    grid-column: 3;
    grid-row: 1;
  }
}
.member { grid-template-columns: 22px minmax(140px, 1.2fr) minmax(130px, 1.4fr) 90px minmax(130px, 1fr) 100px; gap: 12px; padding: 18px; }
.total { font-size: 22px; }
.view-link { grid-column: 6; grid-row: 1; }
.note { grid-column: 2 / 6; font-size: 12px; }
.name { font-size: 14px; }
.job { font-size: 12px; }
@media (max-width: 1100px) { .member { grid-template-columns: 22px minmax(0, 1fr) 90px; } .who { grid-column: 2; } .total { grid-column: 3; grid-row: 1; } .tags, .status { grid-column: 2 / -1; } .note { grid-column: 2 / -1; } .view-link { grid-column: 2 / -1; grid-row: auto; justify-self: start; } }
@media (max-width: 760px) { .member { margin: 10px; border: 1px solid var(--border); border-radius: var(--radius); } }
</style>
