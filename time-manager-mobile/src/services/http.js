import { createApiClient } from '@shared/services/apiClient.js'
import { API_URL } from '@/config/api.js'

export { ApiError } from '@shared/services/apiClient.js'

export async function request(path, options) {
  if (!API_URL) throw new Error('Adresse API manquante : configurer VITE_API_URL.')
  // Jonas adaptera cookies/session, CSRF et expiration au contrat serveur actuel.
  return createApiClient({ baseUrl: API_URL })(path, options)
}
