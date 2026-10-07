<template>
  <li class="member" :class="{ 'is-selected': selected }">
    <input
      class="check"
      type="checkbox"
      :checked="selected"
      :disabled="row.validated || row.departureInWeek || !!row.clockError"
      :aria-label="`Sélectionner ${row.name}`"
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
      <span v-if="row.clockError" class="pill pill-todo"><AppIcon name="alert" />Pointages non vérifiés</span>
      <span v-else-if="row.departureInWeek" class="pill pill-todo"><AppIcon name="clock" />Départ à compléter</span>
      <span v-else-if="row.frequencyExceeded" class="pill pill-warn"><AppIcon name="alert" />Fréquence de nuits à examiner</span>
      <span v-else-if="row.nightRun > maxNights" class="pill pill-danger"><AppIcon name="alert" />{{ row.nightRun }} nuits d’affilée</span>
      <span v-else-if="row.validated" class="pill pill-ok"><AppIcon name="check" />Validée</span>
      <span v-else class="pill pill-todo"><AppIcon name="clock" />À valider</span>
    </p>
    <p class="note"><AppIcon name="message" />{{ row.note || 'Aucune note partagée' }}</p>
    <RouterLink v-if="row.user" class="btn btn-outline btn-sm view-link" :to="{ name: 'workingTimes', params: { userID: row.user.id } }">Voir la fiche</RouterLink>
  </li>
</template>

<script>
import { RouterLink } from 'vue-router'
import AppIcon from '../ui/AppIcon.vue'
import HourTag from '../ui/HourTag.vue'
import { formatHours } from '../../utils/hours'

const ORDER = ['night', 'day', 'oncall', 'sup']

export default {
  name: 'TeamMemberRow',

  components: { AppIcon, HourTag, RouterLink },

  props: {
    row: { type: Object, required: true },
    selected: { type: Boolean, default: false },
    maxNights: { type: Number, required: true },
  },

  emits: ['toggle'],

  computed: {
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
