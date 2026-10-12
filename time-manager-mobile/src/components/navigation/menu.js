import { Building2, Clock, ChartColumn, Calendar, User, Users } from 'lucide-vue-next'

// Onglets de chaque rôle. Tout le monde pointe (Aujourd'hui) et voit ses heures.
// route = nom de la route dans router/index.js ; icon = icône Lucide.
const TODAY = { route: 'today', label: 'Aujourd’hui', icon: Clock }
const HOURS = { route: 'hours', label: 'Mes heures', icon: ChartColumn }
const ACCOUNT = { route: 'account', label: 'Mon compte', icon: User }

export const TABS_BY_ROLE = {
  employee: [TODAY, HOURS, { route: 'planning', label: 'Planning', icon: Calendar }, ACCOUNT],
  manager: [TODAY, HOURS, { route: 'team', label: 'Équipe', icon: Users },
    { route: 'teamPlanning', label: 'Planning', icon: Calendar }, ACCOUNT],
  administrator: [{ route: 'organization', label: 'Accueil', icon: Building2 }, TODAY, HOURS,
    { route: 'team', label: 'Équipes', icon: Users }, ACCOUNT],
}

// Premier écran après la connexion (l'administration arrive sur son tableau de bord, comme sur le web).
export const HOME_BY_ROLE = { administrator: 'organization' }
