<template>
  <div class="rights">
    <PageHeader eyebrow="Administration" title="Équipes et droits" />

    <p class="demo-notice">Droits et règles de démonstration · enregistrés dans ce navigateur. Les permissions du serveur restent celles des rôles et équipes réels.</p>
    <div class="layout">
      <div class="column">
        <RightsTable />

        <section class="card journal">
          <h2 class="card-title">Journal des modifications</h2>
          <p class="card-subtitle">Historique des changements effectués dans cette démonstration.</p>
          <ol class="entries">
            <li v-for="entry in journal" :key="`${entry.at}-${entry.text}`" class="entry">
              <time class="entry-at num">{{ stamp(entry.at) }}</time>
              <p>{{ entry.text }}</p>
            </li>
          </ol>
        </section>
      </div>

      <div class="column">
        <OrgRules />
        <InfoNote title="Aucun droit en secret">
          Les changements sont visibles dans ce journal. Le partage et les notifications seront activés après raccordement du serveur.
        </InfoNote>
      </div>
    </div>
  </div>
</template>

<script>
import InfoNote from '../components/ui/InfoNote.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import OrgRules from '../components/admin/OrgRules.vue'
import RightsTable from '../components/admin/RightsTable.vue'
import { org } from '../services/orgService'

export default {
  name: 'TeamsRights',

  components: { InfoNote, OrgRules, PageHeader, RightsTable },

  computed: {
    journal() {
      return org.journal
    },
  },

  methods: {
    stamp(value) {
      const [day, time] = value.split(' ')
      const date = new Date(`${day}T00:00:00`)
      return `${date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })} · ${time}`
    },
  },
}
</script>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 396px;
  gap: 26px;
  align-items: start;
}

.column {
  display: flex;
  flex-direction: column;
  gap: 22px;
}

.journal {
  padding: 22px 26px 12px;
}

.journal .card-title {
  font-size: 19px;
}

.entries {
  margin: 12px 0 0;
  padding: 0;
  list-style: none;
}

.entry {
  display: grid;
  grid-template-columns: 138px minmax(0, 1fr);
  gap: 12px;
  padding: 12px 0;
  border-top: 1px solid var(--border);
  font-size: 14.5px;
}

.entry:first-child {
  border-top: none;
}

.entry-at {
  font-weight: 700;
  color: var(--title);
}

@media (max-width: 1100px) {
  .layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 560px) {
  .entry {
    grid-template-columns: 1fr;
    gap: 2px;
  }
}
.demo-notice { margin-bottom: 20px; }
</style>
