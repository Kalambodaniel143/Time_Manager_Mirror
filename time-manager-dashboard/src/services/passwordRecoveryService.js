import { request } from './http'
import { AUTH_USE_MOCK } from './organizationService'

async function recovery(path, body) {
  if (AUTH_USE_MOCK) throw new Error('La récupération par email nécessite le mode réel. En démonstration, aucun email n’est envoyé ; utilisez vos identifiants de démonstration.')
  const result = await request(path, { method: 'POST', body: JSON.stringify(body), skipUnauthorizedHandler: true })
  if (!result || typeof result.message !== 'string') throw new Error('Le serveur n’a pas confirmé la demande. Réessayez ou contactez l’administrateur.')
  return result
}
export const requestPasswordRecovery = email => recovery('/auth/forgot-password', { email })
export const resetPassword = (email, code, password) => recovery('/auth/reset-password', { email, code, password })
