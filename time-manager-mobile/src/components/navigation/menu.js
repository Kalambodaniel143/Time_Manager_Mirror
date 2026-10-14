import { t } from '@/i18n/index.js'
import { Building2, Clock, ChartColumn, Calendar, ClipboardCheck, Ellipsis, Inbox, Users } from 'lucide-vue-next'

// Onglets du bas (5 au plus) et pages de « Plus », par rôle.
// route = nom de la route dans router/index.js ; icon = icône Lucide.
const TODAY = { route: 'today', label: t('Aujourd’hui'), icon: Clock }
const HOURS = { route: 'hours', label: t('Mes heures'), icon: ChartColumn }
const REVIEW = { route: 'review', label: t('À traiter'), icon: ClipboardCheck }
const MORE = { route: 'more', label: t('Plus'), icon: Ellipsis }

export const TABS_BY_ROLE = {
  employee: [TODAY, HOURS, { route: 'planning', label: t('Planning'), icon: Calendar }, { route: 'requests', label: t('Demandes'), icon: Inbox }, MORE],
  manager: [TODAY, { route: 'team', label: t('Équipe'), icon: Users }, { route: 'teamPlanning', label: t('Planning'), icon: Calendar }, REVIEW, MORE],
  administrator: [{ route: 'organization', label: t('Accueil'), icon: Building2 }, TODAY, { route: 'team', label: t('Équipes'), icon: Users }, REVIEW, MORE],
}

const link = (route, label, hint) => ({ route, label, hint })
const MINE = [link('hours', t('Mes heures'), t('Graphiques, historique, note de semaine')), link('planning', t('Mon planning'), t('Mes gardes publiées')),
  link('requests', t('Mes demandes'), t('Absences, corrections, échanges'))]
const COMMON = [link('notifications', 'Notifications', t('Plannings publiés, décisions')), link('account', t('Mon compte'), t('Profil, mot de passe, affichage, synchronisation'))]

export const MORE_BY_ROLE = {
  employee: [link('hours', t('Mes heures'), t('Graphiques, historique, note de semaine')), ...COMMON],
  manager: [...MINE, link('weeks', 'Semaines', t('Valider ou clôturer les feuilles')), ...COMMON],
  administrator: [link('payroll', t('Relevé mensuel'), t('Heures et montants du mois')), link('weeks', 'Semaines', t('Valider ou clôturer les feuilles')),
    link('teamPlanning', t('Planning d’équipe'), t('Préparer et publier les gardes')), link('teamsManage', t('Gérer les équipes'), t('Créer, renommer, membres')),
    link('rules', t('Règles et droits'), t('Quotas, majorations, droits des responsables')), link('audit', 'Journal', t('Dernières actions')), ...MINE, ...COMMON],
}

// Premier écran après la connexion (l'administration arrive sur son tableau de bord, comme sur le web).
export const HOME_BY_ROLE = { administrator: 'organization' }
