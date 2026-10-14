import { t } from '@/i18n/index.js'
// Textes qui dépendent du rôle (l'administration n'a pas de responsable au-dessus d'elle).
// Droits du serveur : le responsable corrige les heures de son équipe, l'administration toutes.
export const WHO_FIXES = {
  employee: t('Signalez-le à votre responsable : il peut corriger vos heures.'),
  manager: t('Demandez à l’administration de corriger vos heures.'),
  administrator: t('Vous pouvez corriger vos heures vous-même (temps de travail, sur le web).'),
}

export const WHO_SEES = {
  employee: t('Visible par votre responsable et l’administration'),
  manager: t('Visible par l’administration de votre organisation'),
  administrator: t('Visible par les administrateurs de votre organisation'),
}
