import { request } from './http'
import * as demo from '../mocks/organizationAuth.js'
import { GOTHAM_NAME, isGotham } from '../utils/gotham'

export const AUTH_USE_MOCK = import.meta.env.VITE_AUTH_USE_MOCK !== 'false'

async function call(mock, path, method = 'GET', body, skipUnauthorizedHandler = false) {
  if (AUTH_USE_MOCK) return mock()
  const result = await request(path, { method, skipUnauthorizedHandler, ...(body === undefined ? {} : { body: JSON.stringify(body) }) })
  if (result === undefined) throw new Error('Réponse du serveur invalide.')
  return result
}

async function sessionResult(promise) {
  const result = await promise
  const role = result?.role === 'administrator' ? 'admin' : result?.role
  const userRole = result?.user?.role === 'administrator' ? 'admin' : result?.user?.role
  if (!Number.isInteger(result?.user?.id) || result.user.id <= 0 || !result.organization?.id || !['admin', 'employee', 'manager'].includes(role) || userRole !== role || result.user.organization_id !== result.organization.id || ['first_name', 'last_name', 'email', 'username'].some(key => typeof result.user[key] !== 'string' || !result.user[key].trim())) throw new Error('Réponse de session invalide.')
  if (!isGotham(result.organization)) throw new Error('Votre compte n’est pas rattaché à Gotham City. Contactez le super administrateur.')
  return { ...result, role, user: { ...result.user, role } }
}

export async function loginAccount(body) {
  const session = await sessionResult(call(() => demo.mockLogin(body), '/auth/login', 'POST', body, true))
  if (!AUTH_USE_MOCK && (typeof session.csrf_token !== 'string' || !session.csrf_token.trim())) throw new Error('Réponse de connexion invalide : jeton CSRF absent.')
  return session
}
export const getSession = () => sessionResult(call(() => demo.mockSession(), '/auth/session'))
export const logoutAccount = () => call(() => demo.mockLogout(), '/auth/logout', 'POST', undefined, true)

// Resolve the one organization internally; the applicant cannot choose its name or ID.
export async function getGothamOrganization() {
  const organization = await call(() => demo.mockLookupOrganization(GOTHAM_NAME), `/organizations/lookup?name=${encodeURIComponent(GOTHAM_NAME)}`)
  if (!organization?.id || !isGotham(organization)) throw new Error('Gotham City n’est pas encore configurée. Contactez le super administrateur.')
  return organization
}
export async function joinOrganization({ profile }) {
  let organization
  try { organization = await getGothamOrganization() }
  catch (error) { if (error.status === 404) throw new Error('Gotham City n’est pas encore configurée. Contactez le super administrateur.', { cause: error }); throw error }
  const body = { organization_id: organization.id, profile }
  return call(() => demo.mockJoinOrganization(body), '/join-requests', 'POST', body)
}

export async function getRequestStatus(reference) {
  const receipt = await call(() => demo.mockRequestStatus(reference), '/join-requests/status', 'POST', { reference })
  if (receipt.organization_name && !isGotham({ name: receipt.organization_name })) throw new Error('Cette référence ne concerne pas Gotham City.')
  return receipt
}
export const listJoinRequests = id => call(() => demo.mockListRequests(id), `/organizations/${id}/join-requests`)
export const approveJoinRequest = (orgId, id, password) => call(() => demo.mockApproveRequest(orgId, id, password), `/organizations/${orgId}/join-requests/${id}/approve`, 'POST', { password })
export const rejectJoinRequest = (orgId, id, reason) => call(() => demo.mockRejectRequest(orgId, id, reason), `/organizations/${orgId}/join-requests/${id}/reject`, 'POST', { reason })
export const listMembers = async id => (await call(() => demo.mockListMembers(id), `/organizations/${id}/members`)).map(user => ({ ...user, role: user.role === 'administrator' ? 'admin' : user.role }))
export const setMemberRole = (orgId, id, role) => call(() => demo.mockSetRole(orgId, id, role), `/organizations/${orgId}/members/${id}`, 'PATCH', { role })
