import { auth } from '../stores/auth'
import { request } from './http'
import { mockDeleteOwnAccount } from '../mocks/organizationAuth'

export async function deleteOwnAccount(currentPassword) {
  if (!auth.user) throw new Error('Connectez-vous pour supprimer votre compte.')
  if (typeof currentPassword !== 'string' || !currentPassword) throw new Error('Saisissez votre mot de passe actuel.')
  if (auth.organizationSession) return mockDeleteOwnAccount(currentPassword)
  const result = await request(`/users/${auth.user.id}`, {
    method: 'DELETE',
    body: JSON.stringify({ current_password: currentPassword }),
  })
  if (result !== null) throw new Error('La suppression n’a pas été confirmée par le serveur. Actualisez avant de réessayer.')
  return null
}
