import { auth } from '../stores/auth'
import { buildQuery, request } from './http'
import { workCorrections, workRequestCorrection, workReviewCorrection } from '../mocks/organizationWork'
import { clockDate } from '../utils/missingDeparture'

function checked(item, expectedStatus) {
  if (!item || !Number.isInteger(item.id) || item.id <= 0 || !Number.isInteger(item.user_id) || !Number.isInteger(item.period_id) || typeof item.username !== 'string' || typeof item.reason !== 'string' || !['pending', 'approved', 'rejected'].includes(item.status) || (expectedStatus && item.status !== expectedStatus)) throw new Error('Réponse du service de correction invalide.')
  try { clockDate(item.before.start); clockDate(item.before.end); clockDate(item.proposal.start); clockDate(item.proposal.end) }
  catch { throw new Error('Horaires de la demande de correction invalides.') }
  return item
}
export async function listCorrections(userId) {
  const items = auth.organizationSession ? workCorrections(userId) : await request(`/correction-requests${buildQuery(userId ? { user_id: userId } : {})}`)
  if (!Array.isArray(items)) throw new Error('Liste des demandes de correction invalide.')
  return items.map(item => checked(item))
}
export async function requestCorrection(periodId, attrs) {
  const item = auth.organizationSession ? workRequestCorrection(periodId, attrs) : await request(`/workingtime/${periodId}/correction-requests`, { method: 'POST', body: JSON.stringify({ correction: attrs }) })
  return checked(item, 'pending')
}
export async function reviewCorrection(id, status, reason = '') {
  const item = auth.organizationSession ? workReviewCorrection(id, status, reason) : await request(`/correction-requests/${id}`, { method: 'PATCH', body: JSON.stringify({ status, reason }) })
  return checked(item, status)
}
