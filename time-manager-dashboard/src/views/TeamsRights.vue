<template>
  <div v-if="!demo" class="rights page-stack"><PageHeader :eyebrow="$t(&quot;Administration&quot;)" :title="$t(&quot;Équipes et droits&quot;)" /><RightsTable /><OrgRules /><section class="card section-card page-stack"><h2 class="card-title">{{ $t("Journal des modifications") }}</h2><button class="btn btn-outline" @click="loadJournal">{{ $t("Actualiser le journal") }}</button><p v-if="error" class="field-error" role="alert">{{ $t(error) }}</p><p v-if="!events.length" class="muted">{{ $t("Aucune modification enregistrée.") }}</p><ol class="entries"><li v-for="entry in events" :key="entry.id" class="entry"><time>{{ entry.inserted_at }}</time><div><strong>{{ $t(eventLabel(entry.action)) }}</strong><p class="field-hint">{{ details(entry.details) }}</p></div></li></ol></section><AdminTeams /></div>
  <div v-else class="rights">
    <PageHeader :eyebrow="$t(&quot;Administration&quot;)" :title="$t(&quot;Équipes et droits&quot;)" />

    <p class="demo-notice">{{ $t("Droits et règles de démonstration · enregistrés dans ce navigateur. Les permissions du serveur restent celles des rôles et équipes réels.") }}</p>
    <div class="layout">
      <div class="column">
        <RightsTable />

        <section class="card journal">
          <h2 class="card-title">{{ $t("Journal des modifications") }}</h2>
          <p class="card-subtitle">{{ $t("Historique des changements effectués dans cette démonstration.") }}</p>
          <ol class="entries">
            <li v-for="entry in journal" :key="`${entry.at}-${entry.text}`" class="entry">
              <time class="entry-at num">{{ stamp(entry.at) }}</time>
              <p>{{ $t(entry.text) }}</p>
            </li>
          </ol>
        </section>
      </div>

      <div class="column">
        <OrgRules />
        <InfoNote :title="$t(&quot;Aucun droit en secret&quot;)"> {{ $t("Les changements sont visibles dans ce journal. Le partage et les notifications seront activés après raccordement du serveur.") }} </InfoNote>
      </div>
    </div>
  </div>
</template>

<script>
import { intlLocale } from '../utils/i18n.js'

import InfoNote from '../components/ui/InfoNote.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import OrgRules from '../components/admin/OrgRules.vue'
import RightsTable from '../components/admin/RightsTable.vue'
import AdminTeams from './AdminTeams.vue'
import { getJournal } from '../services/workforceService'
import { org, isDemoData } from '../services/orgService'

export default {
  name: 'TeamsRights',

  components: { AdminTeams, InfoNote, OrgRules, PageHeader, RightsTable },

  data() { return { events: [], error: '' } },
  created() { if (!this.demo) this.loadJournal() },
  computed: {
    demo: isDemoData,
    journal() {
      return org.journal
    },
  },

  methods: {
    async loadJournal() { this.error = ''; try { this.events = await getJournal() } catch (error) { this.error = error.message } },
    eventLabel(action) { const labels = { 'team.created': 'Équipe créée', 'team.updated': 'Équipe modifiée', 'team.deleted': 'Équipe supprimée', 'team.member.added': 'Membre ajouté à une équipe', 'team.member.removed': 'Membre retiré d’une équipe', 'account.updated': 'Compte mis à jour', 'account.role.updated': 'Rôle modifié', 'account.deleted': 'Compte supprimé', 'plan.updated': 'Période du planning modifiée', 'plan.deleted': 'Planning retiré', 'rules.updated': 'Règles mises à jour', 'permissions.updated': 'Permissions modifiées', 'period.created': 'Période ajoutée', 'period.updated': 'Horaires corrigés', 'period.deleted': 'Période supprimée', 'note.updated': 'Note partagée', 'plan.created': 'Planning créé', 'plan.published': 'Planning publié', 'shift.saved': 'Garde enregistrée', 'shift.deleted': 'Garde supprimée', 'sheet.validated': 'Semaine validée', 'sheet.close': 'Semaine clôturée', 'sheet.reopen': 'Semaine rouverte', 'payroll.profile.updated': 'Taux horaire modifié', 'correction.requested': 'Correction demandée', 'correction.approved': 'Correction acceptée', 'correction.rejected': 'Correction refusée', 'absence.payment.updated': 'Heures d’absence confirmées', 'absence.cancelled': 'Absence annulée', 'absence.requested': 'Absence demandée', 'absence.approved': 'Absence acceptée', 'absence.rejected': 'Absence refusée', 'swap.requested': 'Échange demandé', 'swap.consent': 'Accord pour un échange', 'swap.approved': 'Échange effectué', 'swap.rejected': 'Échange refusé' }; return labels[action] || 'Modification enregistrée' },
    details(value) { return [value.user_id ? `Agent ${value.user_id}` : '', value.team_id ? `Équipe ${value.team_id}` : '', value.week || '', value.reason || ''].filter(Boolean).join(' · ') },
    stamp(value) {
      const [day, time] = value.split(' ')
      const date = new Date(`${day}T00:00:00`)
      return `${date.toLocaleDateString(intlLocale(), { day: 'numeric', month: 'short' })} · ${time}`
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
