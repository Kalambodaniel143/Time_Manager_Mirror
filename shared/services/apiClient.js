const ERROR_MESSAGES = {
  network: 'Serveur injoignable. Vérifiez la connexion.',
  timeout: 'Le serveur ne répond pas dans le délai prévu.',
  cancelled: 'Requête annulée.',
  unauthorized: 'Reconnectez-vous.',
  forbidden: 'Vous ne pouvez pas effectuer cette action.',
  conflict: 'Action à vérifier.',
  validation: 'Les données envoyées doivent être vérifiées.',
  server: 'Le serveur rencontre une erreur.',
  invalid_response: 'Réponse du serveur illisible ou incomplète.',
}

function kindForStatus(status) {
  if (status === 401) return 'unauthorized'
  if (status === 403) return 'forbidden'
  if (status === 409) return 'conflict'
  if (status === 422) return 'validation'
  if (status >= 500) return 'server'
  return 'http'
}

export class ApiError extends Error {
  constructor(status, payload = null, kind = kindForStatus(status)) {
    super(ApiError.buildMessage(status, payload, kind))
    this.name = 'ApiError'
    this.status = status
    this.payload = payload
    this.kind = kind
  }

  static buildMessage(status, payload, kind = kindForStatus(status)) {
    const errors = payload?.errors
    if (errors && typeof errors === 'object' && !errors.detail) {
      const details = Object.entries(errors)
        .map(([field, messages]) => `${field} ${[].concat(messages).join(', ')}`)
        .join(' · ')
      if (details) return details
    }
    if (typeof errors?.detail === 'string') return errors.detail
    return ERROR_MESSAGES[kind] || `Erreur ${status}`
  }
}

// Client générique : la session mobile sera branchée séparément par Jonas.
// fetch est injectable pour simuler les coupures sans contacter un serveur.
export function createApiClient({ baseUrl, fetchImpl = (...args) => fetch(...args), timeoutMs = 15000 }) {
  if (typeof baseUrl !== 'string' || !baseUrl.trim()) throw new TypeError('URL API manquante')
  const root = baseUrl.replace(/\/+$/, '')

  return async function request(path, options = {}) {
    if (typeof path !== 'string' || !path.startsWith('/') || path.startsWith('//')) {
      throw new TypeError('Le chemin API doit commencer par un seul /')
    }
    const { signal, timeoutMs: delay = timeoutMs, headers: customHeaders, ...fetchOptions } = options
    if (!Number.isFinite(delay) || delay <= 0) throw new TypeError('Délai API invalide')

    const headers = new Headers(customHeaders)
    if (!headers.has('Accept')) headers.set('Accept', 'application/json')
    if (!headers.has('Content-Type')) headers.set('Content-Type', 'application/json')

    const controller = new AbortController()
    let abortKind = null
    const abort = (kind) => {
      if (controller.signal.aborted) return
      abortKind = kind
      controller.abort()
    }
    const onCancel = () => abort('cancelled')
    signal?.addEventListener('abort', onCancel, { once: true })
    if (signal?.aborted) onCancel()
    const timer = setTimeout(() => abort('timeout'), delay)

    try {
      if (controller.signal.aborted) throw new ApiError(0, null, abortKind)
      const response = await fetchImpl(`${root}${path}`, {
        ...fetchOptions,
        headers,
        signal: controller.signal,
      })
      if (response.status === 204) return null

      let payload
      try {
        payload = await response.json()
      } catch (error) {
        if (controller.signal.aborted) throw error
        if (!response.ok) throw new ApiError(response.status)
        if (error instanceof SyntaxError) throw new ApiError(response.status, null, 'invalid_response')
        throw error
      }

      if (!response.ok) throw new ApiError(response.status, payload)
      if (!payload || typeof payload !== 'object' || !Object.hasOwn(payload, 'data')) {
        throw new ApiError(response.status, null, 'invalid_response')
      }
      return payload.data
    } catch (error) {
      if (controller.signal.aborted) throw new ApiError(0, null, abortKind)
      if (error instanceof ApiError) throw error
      // fetch ne distingue pas une coupure réseau, un échec TLS ou CORS.
      throw new ApiError(0, null, 'network')
    } finally {
      clearTimeout(timer)
      signal?.removeEventListener('abort', onCancel)
    }
    // Ne pas rejouer automatiquement : une réponse perdue n'est pas un échec prouvé.
  }
}
