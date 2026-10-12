import { request } from './http.js'
import { toUtcIso } from '@/ui/dates.js'

// Appels à l'API existante (voir time_manager/lib/time_manager_web/router.ex).
// Même interface que mockApi.js : les écrans ne voient pas la différence.
const post = (path, body) => request(path, { method: 'POST', body })
const put = (path, body) => request(path, { method: 'PUT', body })
const patch = (path, body) => request(path, { method: 'PATCH', body })
const del = (path, body) => request(path, { method: 'DELETE', body })

// Heures des pointages remises en ISO UTC (voir toUtcIso).
const withIsoTime = (clock) => ({ ...clock, time: toUtcIso(clock.time) })

export const api = {
  // Session : login renvoie { csrf_token, role, user, organization } et pose le cookie.
  // Comme le web, pas de création d'organisation ni d'inscription directe :
  // on rejoint l'organisation, le super administrateur crée le compte en acceptant.
  login: (email, password) => post('/auth/login', { email, password }),
  me: () => request('/auth/me'),
  getSession: () => request('/auth/session'),
  logout: () => post('/auth/logout'),

  // Organisations et demandes d'adhésion (docs/CONTRAT_BACKEND_ORGANISATIONS.md)
  lookupOrganization: (name) => request(`/organizations/lookup?name=${encodeURIComponent(name)}`),
  createJoinRequest: (body) => post('/join-requests', body),
  joinRequestStatus: (reference) => post('/join-requests/status', { reference }),
  listJoinRequests: (orgId) => request(`/organizations/${orgId}/join-requests`),
  approveJoinRequest: (orgId, id, password) => post(`/organizations/${orgId}/join-requests/${id}/approve`, { password }),
  rejectJoinRequest: (orgId, id, reason) => post(`/organizations/${orgId}/join-requests/${id}/reject`, { reason }),

  // Pointages et heures
  getClocks: async (userId) => (await request(`/clocks/${userId}`)).map(withIsoTime),
  createClock: async (userId, { kind, time }) =>
    withIsoTime(await post(`/clocks/${userId}`, { clock: { kind, time, status: kind === 'arrival' || kind === 'resume' } })),
  // Départ oublié : ferme le service ouvert ; clockId = dernier pointage connu (contrôlé par le serveur).
  completeClock: async (userId, clockId, time) =>
    withIsoTime(await post(`/clocks/${userId}/${clockId}/complete`, { clock: { time } })),
  getWorkingTimes: (userId) => request(`/workingtime/${userId}`),
  getWorkingTime: (userId, id) => request(`/workingtime/${userId}/${id}`),
  // Corrections : responsable (son équipe, pas soi) ou administration.
  createWorkingTime: (userId, period) => post(`/workingtime/${userId}`, { workingtime: period }),
  updateWorkingTime: (id, period) => put(`/workingtime/${id}`, { workingtime: period }),
  deleteWorkingTime: (id) => del(`/workingtime/${id}`),
  // Le serveur n'a pas encore de route « planning » : rien à afficher.
  getPlanning: async () => [],

  // Comptes
  getUser: (id) => request(`/users/${id}`),
  getUsers: () => request('/users'),
  // Champs lus par le serveur : username, email, first_name, last_name, password (+ current_password pour soi).
  updateUser: (id, user) => put(`/users/${id}`, { user }),
  createUser: (user) => post('/users', { user }),
  updateRole: (id, role) => put(`/users/${id}/role`, { role }),
  // Supprimer son propre compte exige le mot de passe actuel ; l'admin n'en a pas besoin pour un autre.
  deleteUser: (id, currentPassword) => del(`/users/${id}`, currentPassword ? { current_password: currentPassword } : undefined),
  getRoles: () => request('/roles'),
  getMembers: (orgId) => request(`/organizations/${orgId}/members`),
  setMemberRole: (orgId, id, role) => patch(`/organizations/${orgId}/members/${id}`, { role }),

  // Équipes
  getTeams: () => request('/teams'),
  getTeam: (id) => request(`/teams/${id}`),
  createTeam: (team) => post('/teams', { team }),
  updateTeam: (id, team) => put(`/teams/${id}`, { team }),
  deleteTeam: (id) => del(`/teams/${id}`),
  addMember: (id, userId) => post(`/teams/${id}/members`, { user_id: userId }),
  removeMember: (id, userId) => del(`/teams/${id}/members/${userId}`),
}
