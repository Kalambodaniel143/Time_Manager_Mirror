import { request } from './http'

export function listTeams() {
  return request('/teams')
}

export function createTeam(attrs) {
  return request('/teams', { method: 'POST', body: JSON.stringify({ team: attrs }) })
}

export function updateTeam(id, attrs) {
  return request(`/teams/${id}`, { method: 'PUT', body: JSON.stringify({ team: attrs }) })
}

export function deleteTeam(id) {
  return request(`/teams/${id}`, { method: 'DELETE' })
}

export function addMember(teamId, userId) {
  return request(`/teams/${teamId}/members`, { method: 'POST', body: JSON.stringify({ user_id: userId }) })
}

export function removeMember(teamId, userId) {
  return request(`/teams/${teamId}/members/${userId}`, { method: 'DELETE' })
}
