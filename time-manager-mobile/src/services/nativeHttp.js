import { ApiError } from '@shared/services/apiClient.js'
import { noteServerDate } from './serverClock.js'

// Réseau natif Android (cordova-plugin-advanced-http) : pas d'en-tête Origin,
// pas de CORS, cookie de session géré par le plugin. C'est ce qui permet à
// l'application installée de parler au serveur tel qu'il est configuré.
const NETWORK_KINDS = { [-4]: 'timeout', [-8]: 'cancelled' } // autres codes négatifs = réseau

export const hasNativeHttp = () => Boolean(window.cordova?.plugin?.http)

function parse(text) {
  try { return text ? JSON.parse(text) : null } catch { return undefined }
}

export function nativeRequest(url, { method = 'GET', headers = {}, body } = {}) {
  const verb = method.toLowerCase()
  const options = { method: verb, headers: { Accept: 'application/json', ...headers }, serializer: 'json', responseType: 'text', timeout: 15 }
  if (['post', 'put', 'patch'].includes(verb)) options.data = body ?? {}
  // Le plugin n'envoie pas de corps en DELETE : on passe ces champs en paramètres
  // (Phoenix les lit de la même façon et masque « password » dans ses journaux).
  else if (body) options.params = body

  return new Promise((resolve, reject) => {
    window.cordova.plugin.http.sendRequest(url, options, (response) => {
      noteServerDate(response.headers?.date)
      if (response.status === 204) return resolve(null)
      const payload = parse(response.data)
      if (!payload || !Object.hasOwn(payload, 'data')) return reject(new ApiError(response.status, null, 'invalid_response'))
      resolve(payload.data)
    }, (response) => {
      noteServerDate(response.headers?.date)
      // Réseau : on garde la raison donnée par Android (affichée sous le message, pour le diagnostic).
      if (response.status <= 0) return reject(Object.assign(new ApiError(0, null, NETWORK_KINDS[response.status] ?? 'network'), { detail: response.error }))
      reject(new ApiError(response.status, parse(response.error) ?? null))
    })
  })
}
