import { API_URL, MOCK_LATENCY } from '../config'
import { apiErrorMessage } from '../utils/apiErrors'

export class ApiError extends Error {
  constructor(status, payload) {
    super(ApiError.buildMessage(status, payload))
    this.name = 'ApiError'
    this.status = status
    this.payload = payload
  }

  static buildMessage(status, payload) {
    return apiErrorMessage(status, payload)
  }
}

// Set by the auth store / router: where the CSRF token comes from, and what to
// do when the session is no longer valid. Kept as hooks to avoid import cycles.
let csrfTokenProvider = () => null
let unauthorizedHandler = () => {}
let restoreHandler = null
let sessionIdentity = () => null

export function configureHttp({ csrfToken, onUnauthorized, restoreSession, currentUser }) {
  if (csrfToken) csrfTokenProvider = csrfToken
  if (onUnauthorized) unauthorizedHandler = onUnauthorized
  if (restoreSession) restoreHandler = restoreSession
  if (currentUser) sessionIdentity = currentUser
}

export async function request(path, options = {}) {
  const expectedUserId = sessionIdentity()
  const headers = { 'Content-Type': 'application/json', ...options.headers }
  const csrfToken = csrfTokenProvider()
  if (csrfToken) headers['X-CSRF-Token'] = csrfToken

  let response
  try { response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers,
    // Sends the HttpOnly jwt cookie. The API is served under the same origin
    // (/api, through the Nginx or Vite proxy), so no CORS setup is needed.
    credentials: 'same-origin',
  }) } catch (error) { if (error.name === 'AbortError') throw error; throw new ApiError(0, null) }

  if (response.status === 204) return null

  if (response.ok && options.responseType === 'text') return response.text()

  const payload = await response.json().catch(() => null)

  if (response.status === 401 && !options.skipUnauthorizedHandler) {
    if (restoreHandler && expectedUserId && !options.skipSessionRecovery && !options.sessionRecoveryAttempted) {
      const outcome = await restoreHandler(expectedUserId)
      if (outcome === 'restored') return request(path, { ...options, sessionRecoveryAttempted: true })
      if (outcome === 'changed') throw new ApiError(409, { errors: { detail: 'Le compte connecté a changé dans un autre onglet. Vérifiez le compte affiché avant de reprendre cette action.' } })
    }
    if (expectedUserId && sessionIdentity() && expectedUserId !== sessionIdentity()) {
      throw new ApiError(409, { errors: { detail: 'Le compte connecté a changé dans un autre onglet. Vérifiez le compte affiché avant de reprendre cette action.' } })
    }
    unauthorizedHandler(expectedUserId)
  }
  if (!response.ok) throw new ApiError(response.status, payload)

  return payload ? payload.data : null
}

export function mocked(value) {
  return new Promise((resolve) => {
    setTimeout(() => resolve(typeof value === 'function' ? value() : value), MOCK_LATENCY)
  })
}

export function buildQuery(params) {
  const query = new URLSearchParams()

  Object.entries(params || {}).forEach(([key, value]) => {
    if (value !== null && value !== undefined && value !== '') query.append(key, value)
  })

  const serialized = query.toString()
  return serialized ? `?${serialized}` : ''
}
