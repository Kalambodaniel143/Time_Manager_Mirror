// Données fictives pour développer sans serveur (mode MOCK).
// Mot de passe de tous les comptes de démonstration :
export const MOCK_PASSWORD = 'demo1234'

export const ORGANIZATIONS = [{ id: 'org-gotham', name: 'Gotham City', created_at: '2026-09-01T08:00:00Z' }]

const person = (id, first, last, email, role) => ({
  id, username: email, first_name: first, last_name: last, email, role, organization_id: 'org-gotham',
})

export const USERS = [
  person(1, 'Messline', 'Kouassi', 'messline@example.com', 'employee'),
  person(2, 'Lucie', 'Ferreira', 'manager@example.com', 'manager'),
  person(3, 'Nando', 'Martin', 'admin@example.com', 'administrator'),
  person(4, 'Karim', 'Benali', 'karim@example.com', 'employee'),
  person(5, 'Sara', 'Ortiz', 'sara@example.com', 'employee'),
  person(6, 'Hugo', 'Martin', 'hugo@example.com', 'employee'),
]

export const TEAMS = [
  { id: 1, name: 'Voirie · Nuit', managerId: 2, memberIds: [1, 4, 5, 6], organizationId: 'org-gotham' },
  { id: 2, name: 'Espaces publics', managerId: 3, memberIds: [2], organizationId: 'org-gotham' },
]

// Semaine type (lundi → dimanche), décalée d'un jour par agent.
export const WEEK_PATTERN = [
  { type: 'jour', start: '05:00', end: '12:00' },
  { type: 'nuit', start: '22:00', end: '06:00' },
  { type: 'nuit', start: '22:00', end: '06:00' },
  { type: 'repos' },
  { type: 'jour', start: '05:00', end: '12:00' },
  { type: 'astreinte', start: '22:00', end: '06:00' },
  { type: 'repos' },
]
