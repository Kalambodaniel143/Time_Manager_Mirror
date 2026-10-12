// Textes qui dépendent du rôle (l'administration n'a pas de responsable au-dessus d'elle).
// Droits du serveur : le responsable corrige les heures de son équipe, l'administration toutes.
export const WHO_FIXES = {
  employee: 'Signalez-le à votre responsable : il peut corriger vos heures.',
  manager: 'Demandez à l’administration de corriger vos heures.',
  administrator: 'Vous pouvez corriger vos heures vous-même (temps de travail, sur le web).',
}

export const WHO_SEES = {
  employee: 'Visible par votre responsable et l’administration',
  manager: 'Visible par l’administration de votre organisation',
  administrator: 'Visible par les administrateurs de votre organisation',
}
