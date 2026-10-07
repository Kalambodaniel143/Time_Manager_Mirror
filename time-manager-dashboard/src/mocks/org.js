export const PERSONAS = {
  employee: {
    role: 'employee',
    username: 'marie.dubois',
    email: 'marie.dubois@gotham.gov',
    name: 'Marie Dubois',
    job: 'Agente de voirie',
    space: 'Espace employé',
  },
  manager: {
    role: 'manager',
    username: 'lucie.ferreira',
    email: 'lucie.ferreira@gotham.gov',
    name: 'Lucie Ferreira',
    job: 'Manager · voirie nuit',
    space: 'Espace manager',
  },
  admin: {
    role: 'admin',
    username: 'albert.r',
    email: 'albert.r@gotham.gov',
    name: 'Albert R.',
    job: 'Ressources humaines',
    space: 'Administration',
  },
}

export const TEAM = {
  name: 'Équipe voirie nuit',
  manager: { username: 'lucie.ferreira', short: 'Lucie F.' },
  members: [
    { username: 'karim.benali', name: 'Karim Benali', short: 'Karim B.', job: 'Agent de voirie', unit: 'Voirie' },
    { username: 'sara.ortiz', name: 'Sara Ortiz', short: 'Sara O.', job: 'Jardinière', unit: 'Espaces verts' },
    { username: 'john.doe', name: 'John Doe', short: 'John D.', job: 'Nettoyage des scènes de crime', unit: 'Nettoyage' },
    { username: 'marie.dubois', name: 'Marie Dubois', short: 'Marie D.', job: 'Agente de voirie', unit: 'Voirie' },
    { username: 'hugo.lin', name: 'Hugo Lin', short: 'Hugo L.', job: 'Agent de voirie', unit: 'Voirie' },
    { username: 'paula.ibanez', name: 'Paula Ibáñez', short: 'Paula I.', job: 'Agente de voirie', unit: 'Voirie' },
  ],
}

export const SHIFT_HOURS = {
  day: { from: '05:00', to: '12:00', hours: 7 },
  night: { from: '22:00', to: '06:00', hours: 8 },
  oncall: { from: '22:00', to: '06:00', hours: 8 },
}

export const EMPLOYEE_PLAN = [
  'day', 'night', 'night', 'rest', 'day', 'oncall', 'rest',
  'day', 'day', 'rest', 'night', 'night', 'rest', 'rest',
]

export const EMPLOYEE_PLACES = ['Voirie · secteur Narrows', 'Voirie · Old Gotham', 'Voirie · Burnley', 'Voirie · Otisburg']

export const TEAM_PLAN = {
  'karim.benali': ['rest', 'night', 'night', 'night', 'rest', 'day', 'day', 'day', 'rest', 'night', 'night', 'rest', 'rest', 'day'],
  'hugo.lin': ['day', 'day', 'day', 'day', 'rest', 'rest', 'night', 'night', 'rest', 'day', 'day', 'day', 'rest', 'rest'],
  'marie.dubois': ['day', 'night', 'night', 'rest', 'day', 'oncall', 'day', 'day', 'day', 'rest', 'night', 'night', 'rest', 'rest'],
  'john.doe': ['night', 'night', 'rest', 'rest', 'night', 'night', 'rest', 'rest', 'night', 'night', 'rest', 'rest', 'day', 'day'],
  'sara.ortiz': ['day', 'day', 'day', 'day', 'day', 'rest', 'rest', 'day', 'day', 'day', 'day', 'day', 'rest', 'rest'],
  'paula.ibanez': ['day', 'day', 'rest', 'leave', 'leave', 'leave', 'leave', 'leave', 'day', 'day', 'day', 'rest', 'night', 'rest'],
}

export const NOTES = {
  'john.doe': 'Semaine calme, prévenu lundi. J’ai avancé le plan d’inhumation comme convenu.',
  'marie.dubois': 'Samedi : astreinte Bat-signal de 02:10 à 04:10.',
}

export const RULES = {
  maxConsecutiveNights: 2,
  maxNightsPerWeek: 0,
  maxNightsPerMonth: 0,
  overtimeThreshold: 40,
  publishDaysAhead: 14,
}

export const MANAGER_RIGHTS = [
  { id: 'gordon', name: 'Chef Gordon', team: 'Police · patrouilles de nuit', validate: true, correct: true, publish: true },
  { id: 'lucie', name: 'Lucie F.', team: 'Voirie · équipe nuit', validate: true, correct: true, publish: false },
  { id: 'lea', name: 'Léa T.', team: 'Espaces verts', validate: true, correct: false, publish: false },
  { id: 'omar', name: 'Omar C.', team: 'Nettoyage', validate: true, correct: true, publish: true },
]

export const JOURNAL = [
  { daysAgo: 3, time: '14:12', text: 'Omar C. peut publier le planning de l’équipe Nettoyage. Exemple de changement de droit.' },
  { daysAgo: 11, time: '16:05', text: 'Seuil de nuits d’affilée de la Police passé de 3 à 2, à la demande du chef Gordon. Exemple de changement de règle.' },
  { daysAgo: 18, time: '11:30', text: 'Lucie F. ne publie plus le planning (changement d’équipe). Exemple de changement de droit.' },
]

export const PAYROLL = [
  { service: 'Voirie', day: 3920, night: 980, sup: 164, recup: 40, oncall: 120, leave: 380 },
  { service: 'Police', day: 4100, night: 1020, sup: 190, recup: 32, oncall: 150, leave: 410 },
  { service: 'Espaces verts', day: 2460, night: 0, sup: 24, recup: 12, oncall: 0, leave: 214 },
  { service: 'Nettoyage', day: 2000, night: 136, sup: 40, recup: 12, oncall: 40, leave: 200 },
]
