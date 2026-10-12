import { ApiError } from '@shared/services/apiClient.js'
import { read, write } from '@/storage/database.js'
import { readSession } from '@/storage/sessionStorage.js'
import { MOCK_PASSWORD, ORGANIZATIONS, USERS, TEAMS } from '@/data/mock.js'

// Base fictive persistante : comptes et équipes modifiables comme sur le serveur.
export const db = () => ({ organizations: ORGANIZATIONS, joinRequests: [], users: USERS, teams: TEAMS, ...read('mock:db:v3') })
export const save = (data) => write('mock:db:v3', data)
export const findUser = (id) => db().users.find((u) => u.id === Number(id))

// Lit la base, applique fn, enregistre : une « transaction » du faux serveur.
export function change(fn) {
  const data = db()
  const result = fn(data)
  save(data)
  return result
}

// Démo seulement : mot de passe gardé en clair dans la base fictive (jamais sur un vrai serveur).
export const passwordOf = (user) => user.password ?? MOCK_PASSWORD
// Jamais renvoyé au client, comme le vrai serveur.
export const publicUser = ({ password, unverified, ...user }) => user

export const fail = (status, detail) => new ApiError(status, { errors: { detail } })

// Utilisateur connecté (le vrai serveur le lit dans le cookie JWT).
export function currentUser() {
  const me = findUser(readSession()?.user?.id)
  if (!me) throw fail(401, 'Unauthorized')
  return me
}

// Mêmes règles que time_manager/lib/time_manager/authorization.ex :
// les organisations sont étanches, puis rôle + périmètre.
export const isAdmin = (u) => u.role === 'administrator'
export const sameOrg = (a, b) => Boolean(a && b) && a.organization_id === b.organization_id
export const managedIds = (managerId) =>
  db().teams.filter((t) => t.managerId === managerId).flatMap((t) => t.memberIds)
export const canView = (me, id) => me.id === Number(id) || (sameOrg(me, findUser(id)) &&
  (isAdmin(me) || (me.role === 'manager' && managedIds(me.id).includes(Number(id)))))

// Session telle que la renvoie le serveur ({ role, user, organization }).
export const sessionOf = (user) => ({
  role: user.role,
  user: publicUser(user),
  organization: db().organizations.find((o) => o.id === user.organization_id) ?? null,
})

export function allow(condition) {
  if (!condition) throw fail(403, 'Forbidden')
}

export const teamJson = (t, withMembers = true) => ({
  id: t.id,
  name: t.name,
  manager: findUser(t.managerId) ? publicUser(findUser(t.managerId)) : null,
  members: withMembers ? t.memberIds.map(findUser).filter(Boolean).map(publicUser) : [],
})

// Qui corrige les heures : l'administration de l'organisation, ou le responsable
// de l'équipe de l'agent (jamais ses propres heures).
export const canEditHours = (me, id) => (isAdmin(me) && sameOrg(me, findUser(id))) ||
  (me.role === 'manager' && me.id !== Number(id) && managedIds(me.id).includes(Number(id)))
