import { allow, change, db, fail, findUser, isAdmin, teamJson } from './mock/db.js'
import { server } from './mock/server.js'

// Équipes du faux serveur (règles de team_controller.ex) : seule l'administration les compose.
function team(data, id) {
  const found = data.teams.find((t) => t.id === Number(id))
  if (!found) throw fail(404, 'Not Found')
  return found
}

function checkManager(managerId) {
  if (managerId && !['manager', 'administrator'].includes(findUser(managerId)?.role)) {
    throw fail(422, 'manager_id must have the manager role')
  }
}

export const mockAdminApi = {
  getTeams: () => server((me) => db().teams
    .filter((t) => (isAdmin(me) && t.organizationId === me.organization_id) || t.managerId === me.id || t.memberIds.includes(me.id))
    .map((t) => teamJson(t, isAdmin(me) || t.managerId === me.id))),
  getTeam: (id) => server((me) => {
    const t = team(db(), id)
    allow(isAdmin(me) || t.managerId === me.id)
    return teamJson(t)
  }),
  createTeam: ({ name, manager_id }) => server((me) => change((data) => {
    allow(isAdmin(me))
    checkManager(manager_id)
    const created = { id: Math.max(0, ...data.teams.map((t) => t.id)) + 1, name, managerId: manager_id ?? null, memberIds: [], organizationId: me.organization_id }
    data.teams.push(created)
    return teamJson(created)
  })),
  updateTeam: (id, { name, manager_id }) => server((me) => change((data) => {
    allow(isAdmin(me))
    checkManager(manager_id)
    return teamJson(Object.assign(team(data, id), { name, managerId: manager_id ?? null }))
  })),
  deleteTeam: (id) => server((me) => change((data) => {
    allow(isAdmin(me))
    data.teams = data.teams.filter((t) => t.id !== Number(id))
    return null
  })),
  addMember: (id, userId) => server((me) => change((data) => {
    allow(isAdmin(me))
    const t = team(data, id)
    if (!t.memberIds.includes(Number(userId))) t.memberIds.push(Number(userId))
    return teamJson(t)
  })),
  removeMember: (id, userId) => server((me) => change((data) => {
    allow(isAdmin(me))
    const t = team(data, id)
    t.memberIds = t.memberIds.filter((m) => m !== Number(userId))
    return teamJson(t)
  })),
}
