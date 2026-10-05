import { API_URL } from '../config'
import { ApiError } from './http'
import * as demo from '../mocks/organizationAuth.js'

// Le circuit reste testable sans modifier le backend existant.
export const AUTH_USE_MOCK = import.meta.env.VITE_AUTH_USE_MOCK !== 'false'

async function authRequest(path, method = 'GET', body) {
  const response = await fetch(`${API_URL}${path}`, {
    method,
    credentials: 'include',
    headers: { 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  })
  if (response.status === 204) return null
  const payload = await response.json().catch(() => null)
  if (!response.ok) throw new ApiError(response.status, payload)
  if (!payload || !Object.hasOwn(payload, 'data')) throw new Error('Réponse du serveur invalide.')
  return payload.data
}

async function call(mock, path, method, body) {
  return AUTH_USE_MOCK ? mock() : authRequest(path, method, body)
}

async function sessionResult(promise) {
  const session = await promise
  if (!Number.isInteger(session?.user?.id) || session.user.id <= 0 || !session.organization?.id || !session.organization.name || !['admin', 'employee', 'manager'].includes(session.role) || session.user.role !== session.role || session.user.organization_id !== session.organization.id || ['first_name', 'last_name', 'email', 'username'].some((key) => typeof session.user[key] !== 'string' || !session.user[key].trim())) {
    throw new Error('Réponse de session invalide.')
  }
  return session
}

export const createOrganization = (body) => sessionResult(call(() => demo.mockCreateOrganization(body), '/organizations', 'POST', body))
export const loginAccount = (body) => sessionResult(call(() => demo.mockLogin(body), '/auth/login', 'POST', body))
export const getSession = () => sessionResult(call(() => demo.mockSession(), '/auth/session'))
export const logoutAccount = () => call(() => demo.mockLogout(), '/auth/logout', 'POST')
export const lookupOrganization = (name) => call(() => demo.mockLookupOrganization(name), `/organizations/lookup?name=${encodeURIComponent(name)}`)
export const joinOrganization = (body) => call(() => demo.mockJoinOrganization(body), '/join-requests', 'POST', body)
export const getRequestStatus = (reference) => call(() => demo.mockRequestStatus(reference), '/join-requests/status', 'POST', { reference })
export const listJoinRequests = (id) => call(() => demo.mockListRequests(id), `/organizations/${id}/join-requests`)
export const approveJoinRequest = (orgId, id, password) => call(() => demo.mockApproveRequest(orgId, id, password), `/organizations/${orgId}/join-requests/${id}/approve`, 'POST', { password })
export const rejectJoinRequest = (orgId, id, reason) => call(() => demo.mockRejectRequest(orgId, id, reason), `/organizations/${orgId}/join-requests/${id}/reject`, 'POST', { reason })
export const listMembers = (id) => call(() => demo.mockListMembers(id), `/organizations/${id}/members`)
export const setMemberRole = (orgId, id, role) => call(() => demo.mockSetRole(orgId, id, role), `/organizations/${orgId}/members/${id}`, 'PATCH', { role })
