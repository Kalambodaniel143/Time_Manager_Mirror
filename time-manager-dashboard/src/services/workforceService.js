import { reactive, watch } from 'vue'
import { request, requestHistory, buildQuery } from './http'
import { org } from './orgService'
import { auth } from '../stores/auth'

export const workforce = reactive({ ready: false, loading: false, error: '', permissions: [], preferences: {}, notifications: [], version: 0 })
const call = async (path, method = 'GET', body) => {
  const result = await request(path, { method, ...(body === undefined ? {} : { body: JSON.stringify(body) }) })
  if (!result || typeof result !== 'object') throw new Error('Réponse du serveur invalide.')
  return result
}
const rows = async path => {
  const history = /^\/(shift-swaps|absence-requests|audit-events|notifications|correction-requests)(\?|$)/.test(path)
  const result = history ? await requestHistory(path) : await call(path)
  if (!Array.isArray(result)) throw new Error('Liste du serveur invalide.')
  return result
}

export function clearWorkforce() {
  workforce.version += 1
  Object.assign(workforce, { ready: false, loading: false, error: '', permissions: [], preferences: {}, notifications: [] })
  Object.assign(org.rules, { maxConsecutiveNights: Infinity, maxNightsPerWeek: 0, maxNightsPerMonth: 0, overtimeThreshold: Infinity, publishDaysAhead: 0 })
}
export async function loadContext() {
  const version = ++workforce.version
  const userId = auth.user?.id
  workforce.loading = true; workforce.error = ''
  try {
    const data = await call('/workforce/context')
    if (!data?.rules || !Array.isArray(data.permissions) || !data.preferences) throw new Error('Contexte du compte invalide.')
    if (version === workforce.version && userId === auth.user?.id) {
      Object.assign(org.rules, data.rules)
      workforce.permissions = data.permissions; workforce.preferences = data.preferences; workforce.ready = true
    }
    return data
  } catch (error) {
    if (version === workforce.version) { workforce.ready = false; workforce.error = error.status === 404 ? 'Les nouvelles fonctionnalités ne sont pas encore activées sur ce serveur.' : error.message }
    throw error
  } finally { if (version === workforce.version) workforce.loading = false }
}
export const saveRules = (id, rules) => call(`/organizations/${id}/rules`, 'PATCH', { rules })
export const savePermissions = (id, permissions) => call(`/teams/${id}/permissions`, 'PATCH', { permissions })
export const getNote = (id, week) => call(`/users/${id}/week-notes/${week}`)
export const saveNote = (id, week, note) => call(`/users/${id}/week-notes/${week}`, 'PUT', { note })
export const getSheets = week => rows(`/weekly-sheets${buildQuery({ week })}`)
export const validateSheets = (week, userIds) => call('/weekly-sheets/validate', 'POST', { week, user_ids: userIds })
export const transitionSheet = (id, week, action, reason) => call(`/weekly-sheets/${id}/${week}/${action}`, 'POST', { reason })
export const listPlans = (filters = {}) => rows(`/plans${buildQuery(filters)}`)
export const getPlan = id => call(`/plans/${id}`)
export const updatePlan = (id, attrs) => call(`/plans/${id}`, 'PATCH', attrs)
export const deletePlan = (id, revision, reason) => call(`/plans/${id}`, 'DELETE', { revision, reason })
export const createPlan = (id, plan) => call(`/teams/${id}/plans`, 'POST', { plan })
export const saveShift = (planId, id, shift) => call(`/plans/${planId}/shifts${id ? `/${id}` : ''}`, id ? 'PUT' : 'POST', { shift })
export const deleteShift = (planId, id, revision) => call(`/plans/${planId}/shifts/${id}`, 'DELETE', { revision })
export const publishPlan = (id, revision) => call(`/plans/${id}/publish`, 'POST', { revision })
export const listSwaps = () => rows('/shift-swaps')
export const requestSwap = (shiftId, targetId, reason) => call('/shift-swaps', 'POST', { shift_id: shiftId, target_shift_id: targetId, reason })
export const consentSwap = (id, accepted) => call(`/shift-swaps/${id}/consent`, 'PATCH', { accepted })
export const reviewSwap = (id, status, reason) => call(`/shift-swaps/${id}`, 'PATCH', { status, reason })
export const listAbsences = () => rows('/absence-requests')
export const requestAbsence = attrs => call('/absence-requests', 'POST', attrs)
export const setAbsencePayment = (id, hours) => call(`/absence-requests/${id}/payment`, 'PATCH', { payable_hours: hours })
export const cancelAbsence = (id, reason) => call(`/absence-requests/${id}/cancel`, 'POST', { reason })
export const reviewAbsence = (id, status, reason, payableHours) => call(`/absence-requests/${id}`, 'PATCH', { status, reason, ...(payableHours === undefined ? {} : { payable_hours: payableHours }) })
export const exportPayroll = month => request(`/payroll/export${buildQuery({ month })}`, { responseType: 'text' })
export const getPayroll = async month => { const report = await call(`/payroll${buildQuery({ month })}`); if (!Array.isArray(report.rows) || !report.rules || typeof report.total !== 'number') throw new Error('Relevé du serveur invalide.'); return report }
export const getPayProfile = id => call(`/users/${id}/payroll-profile`)
export const savePayProfile = (id, attrs) => call(`/users/${id}/payroll-profile`, 'PUT', attrs)
export async function savePreferences(settings) {
  const userId = auth.user?.id
  const version = workforce.version
  const prefs = await call('/auth/preferences', 'PATCH', settings)
  if (userId === auth.user?.id && version === workforce.version) workforce.preferences = prefs
  return prefs
}
export const getJournal = () => rows('/audit-events')
export const listNotifications = () => rows('/notifications')
export const readNotification = id => call(`/notifications/${id}/read`, 'PATCH', {})
export function canReviewTarget(id, key = 'validate') {
  if (!auth.user || auth.user.id === id) return false
  if (auth.user.role === 'administrator') return true
  return auth.user.role === 'manager' && workforce.ready && workforce.permissions.some(row => row.manager_id === auth.user.id && row[key] && row.member_ids?.includes(id))
}

// Effacement immédiat, même si le nouveau compte arrive sans passer par une déconnexion.
watch(() => auth.user?.id, clearWorkforce, { flush: 'sync' })
