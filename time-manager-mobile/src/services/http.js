import { t } from '@/i18n/index.js'
import { createApiClient } from '@shared/services/apiClient.js'
import { API_URL } from '@/config/api.js'
import { hasNativeHttp, nativeRequest } from './nativeHttp.js'
import { noteServerDate } from './serverClock.js'

// fetch qui note l'heure du serveur (en-tête Date) à chaque réponse.
async function fetchNotingDate(...args) {
  const response = await fetch(...args)
  noteServerDate(response.headers.get('date'))
  return response
}

// Le serveur pose un cookie HttpOnly (JWT) et attend le jeton CSRF dans un en-tête.
let csrfToken = null
export const setCsrfToken = (token) => { csrfToken = token }

// Téléphone : réseau natif. Navigateur : fetch vers /api (relayé par Vite).
export async function request(path, { method = 'GET', body } = {}) {
  if (!API_URL) throw new Error(t('Adresse du serveur manquante : renseigner VITE_API_URL dans .env.local.'))
  const headers = csrfToken ? { 'X-CSRF-Token': csrfToken } : {}
  if (hasNativeHttp()) return nativeRequest(`${API_URL.replace(/\/+$/, '')}${path}`, { method, headers, body })
  return createApiClient({ baseUrl: API_URL, fetchImpl: fetchNotingDate })(path, {
    method,
    credentials: 'include',
    headers,
    body: body && JSON.stringify(body),
  })
}
