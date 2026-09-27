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

    if (errors && errors.detail) return errors.detail

    return `Erreur ${status}`
  }
}

export async function request(path, options = {}) {
  const response = await fetch(`${API_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })

  if (response.status === 204) return null

  const payload = await response.json().catch(() => null)

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
