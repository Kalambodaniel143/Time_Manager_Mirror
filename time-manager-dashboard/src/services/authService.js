import { USE_MOCK } from '../config'
import { mocked, request } from './http'
import { mockLogin, mockLogout, mockMe, mockRegister } from '../mocks/auth'

// Login and register answer { csrf_token, user }; the JWT arrives as an
// HttpOnly cookie that this code never sees.
export function login(email, password) {
  if (USE_MOCK) return mocked(() => mockLogin(email, password))

  return request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({ email, password }),
    skipUnauthorizedHandler: true,
  })
}

export function register(attrs) {
  if (USE_MOCK) return mocked(() => mockRegister(attrs))

  return request('/auth/register', { method: 'POST', body: JSON.stringify({ user: attrs }) })
}

export function verifyEmail(email, code) {
  if (USE_MOCK) return mocked(() => mockLogin(email, ''))

  return request('/auth/verify-email', {
    method: 'POST',
    body: JSON.stringify({ email, code }),
    skipUnauthorizedHandler: true,
  })
}

export function resendVerification(email) {
  return request('/auth/resend-verification', {
    method: 'POST',
    body: JSON.stringify({ email }),
    skipUnauthorizedHandler: true,
  })
}

export function me() {
  if (USE_MOCK) return mocked(() => mockMe())

  return request('/auth/me', { skipUnauthorizedHandler: true })
}

export function logout() {
  if (USE_MOCK) return mocked(() => mockLogout())

  return request('/auth/logout', { method: 'POST', skipUnauthorizedHandler: true })
}

export function listRoles() {
  if (USE_MOCK) return mocked(() => ['employee', 'manager', 'administrator'].map((name, id) => ({ id: id + 1, name })))

  return request('/roles')
}

export function updateRole(userId, role) {
  return request(`/users/${userId}/role`, { method: 'PUT', body: JSON.stringify({ role }) })
}
