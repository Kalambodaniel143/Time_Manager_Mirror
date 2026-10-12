import { ApiError } from '@shared/services/apiClient.js'
import { read, write } from '@/storage/database.js'
import { currentUser, fail } from './db.js'

// Réglages de la carte « Outils de test » (Mon compte, mode démo seulement).
export const getMockSettings = () =>
  read('mock:settings', { serverDown: false, loseNextResponse: false, sessionExpired: false })
export const setMockSetting = (name, value) => write('mock:settings', { ...getMockSettings(), [name]: value })

export const networkError = () => new ApiError(0, null, 'network')

// Simule un aller-retour réseau : délai, serveur coupé, session expirée.
// answer(me) reçoit l'utilisateur connecté, comme un contrôleur Phoenix.
export async function server(answer, { isLogin = false } = {}) {
  await new Promise((resolve) => setTimeout(resolve, 250))
  const settings = getMockSettings()
  if (settings.serverDown || !navigator.onLine) throw networkError()
  if (settings.sessionExpired && !isLogin) throw fail(401, 'Unauthorized')
  return answer(isLogin ? null : currentUser())
}
