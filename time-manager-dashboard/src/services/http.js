import { API_URL, MOCK_LATENCY } from '../config'

export class ApiError extends Error {
  constructor(status, payload) {
    super(ApiError.buildMessage(status, payload))
    this.name = 'ApiError'
    this.status = status
    this.payload = payload
  }

  static buildMessage(status, payload) {
    const errors = payload && payload.errors

    if (errors && typeof errors === 'object' && !errors.detail) {
      const details = Object.entries(errors)
        .map(([field, messages]) => `${field} ${[].concat(messages).join(', ')}`)
        .join(' · ')

      if (details) return details
    }

    if (status === 403) return 'Accès refusé'
    if (errors && errors.detail) return errors.detail

    return `Erreur ${status}`
  }
}

// Set by the auth store / router: where the CSRF token comes from, and what to
// do when the session is no longer valid. Kept as hooks to avoid import cycles.
let csrfTokenProvider = () => null
let unauthorizedHandler = () => {}

export function configureHttp({ csrfToken, onUnauthorized }) {
  if (csrfToken) csrfTokenProvider = csrfToken
  if (onUnauthorized) unauthorizedHandler = onUnauthorized
}

export async function request(path, options = {}) {
  const headers = { 'Content-Type': 'application/json', ...options.headers }
  const csrfToken = csrfTokenProvider()
  if (csrfToken) headers['X-CSRF-Token'] = csrfToken

  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers,
    // Sends the HttpOnly jwt cookie. The API is served under the same origin
    // (/api, through the Nginx or Vite proxy), so no CORS setup is needed.
    credentials: 'same-origin',
  })

  // Une réponse de l'ancien compte ne doit ni remplir l'écran ni déconnecter le nouveau.
  const checkSession = () => {
    if (csrfToken !== csrfTokenProvider()) throw new ApiError(409, { errors: { detail: 'Le compte a changé. Recommencez cette action.' } })
  }
  checkSession()
  if (response.status === 204) return null

  if (response.ok && options.responseType === 'text') { const text = await response.text(); checkSession(); return text }

  const payload = await response.json().catch(() => null)

  checkSession()
  if (response.status === 401 && !options.skipUnauthorizedHandler) unauthorizedHandler()
  if (!response.ok) throw new ApiError(response.status, payload)

  const data = payload ? payload.data : null
  return options.page ? { data, next: response.headers?.get('x-next-cursor') || null } : data
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

// L'API borne chaque page ; le navigateur refuse aussi un historique démesuré.
export async function requestHistory(path) {
  const initialToken = csrfTokenProvider()
  const rows = []
  let cursor = null
  for (let page = 0; page < 20; page += 1) {
    if (csrfTokenProvider() !== initialToken) throw new ApiError(409, { errors: { detail: 'Le compte a changé. Recommencez cette action.' } })
    const suffix = cursor ? `${path.includes('?') ? '&' : '?'}cursor=${encodeURIComponent(cursor)}` : ''
    const result = await request(path + suffix, { page: true })
    if (!Array.isArray(result.data)) throw new Error('Liste de l’historique du serveur invalide.')
    rows.push(...result.data)
    if (!result.next) return rows
    if (!/^\d+$/.test(result.next) || Number(result.next) <= Number(cursor)) throw new Error('Pagination du serveur invalide.')
    cursor = result.next
  }
  throw new Error('Historique trop volumineux. Réduisez la période demandée.')
}
