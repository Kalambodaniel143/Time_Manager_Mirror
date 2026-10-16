import { request } from './http.js'

// Nouvelles routes du serveur (contrat backend, section 13) : planning, demandes,
// semaines, paie, règles, journal, notifications. Toutes sous /api, avec cookie + CSRF.
const post = (path, body) => request(path, { method: 'POST', body })
const put = (path, body) => request(path, { method: 'PUT', body })
const patch = (path, body) => request(path, { method: 'PATCH', body })
const del = (path, body) => request(path, { method: 'DELETE', body })
const query = (params) => new URLSearchParams(params).toString()

export const workforceApi = {
  getContext: () => request('/workforce/context'),

  // Règles de l'organisation et droits des équipes (administration)
  getRules: (orgId) => request(`/organizations/${orgId}/rules`),
  saveRules: (orgId, rules) => patch(`/organizations/${orgId}/rules`, { rules }),
  getTeamPermissions: (teamId) => request(`/teams/${teamId}/permissions`),
  saveTeamPermissions: (teamId, permissions) => patch(`/teams/${teamId}/permissions`, { permissions }),

  // Semaines : note du salarié, validation et clôture par un responsable
  getWeekNote: (userId, week) => request(`/users/${userId}/week-notes/${week}`),
  saveWeekNote: (userId, week, note) => put(`/users/${userId}/week-notes/${week}`, { note }),
  getWeeklySheets: (week) => request(`/weekly-sheets?${query({ week })}`),
  validateWeeks: (week, userIds) => post('/weekly-sheets/validate', { week, user_ids: userIds }),
  weekAction: (userId, week, action, reason) => post(`/weekly-sheets/${userId}/${week}/${action}`, { reason }),

  // Corrections d'heures : le salarié propose, un autre responsable décide
  getCorrections: (userId) => request(`/correction-requests${userId ? `?${query({ user_id: userId })}` : ''}`),
  proposeCorrection: (periodId, correction) => post(`/workingtime/${periodId}/correction-requests`, { correction }),
  decideCorrection: (id, status, reason) => patch(`/correction-requests/${id}`, { status, reason }),

  // Plannings et gardes
  getPlans: (from, to) => request(`/plans?${query({ from, to })}`),
  getPlan: (id) => request(`/plans/${id}`),
  createPlan: (teamId, start, days) => post(`/teams/${teamId}/plans`, { plan: { start, days } }),
  updatePlan: (id, plan, revision) => patch(`/plans/${id}`, { plan, revision }),
  deletePlan: (id, revision, reason) => del(`/plans/${id}`, { revision, reason }),
  addShift: (planId, shift) => post(`/plans/${planId}/shifts`, { shift }),
  updateShift: (planId, id, shift) => put(`/plans/${planId}/shifts/${id}`, { shift }),
  deleteShift: (planId, id, revision) => del(`/plans/${planId}/shifts/${id}`, { revision }),
  publishPlan: (id, revision) => post(`/plans/${id}/publish`, { revision }),

  // Échanges de gardes
  getSwaps: () => request('/shift-swaps'),
  proposeSwap: (shiftId, targetShiftId, reason) => post('/shift-swaps', { shift_id: shiftId, target_shift_id: targetShiftId, reason }),
  consentSwap: (id, accepted) => patch(`/shift-swaps/${id}/consent`, { accepted }),
  decideSwap: (id, status, reason) => patch(`/shift-swaps/${id}`, { status, reason }),

  // Absences (congé, maladie, récupération)
  getAbsences: () => request('/absence-requests'),
  requestAbsence: (absence) => post('/absence-requests', absence),
  decideAbsence: (id, decision) => patch(`/absence-requests/${id}`, decision),
  cancelAbsence: (id, reason) => post(`/absence-requests/${id}/cancel`, { reason }),

  // Administration : journal
  getAuditEvents: () => request('/audit-events'),

  // Notifications personnelles
  getNotifications: () => request('/notifications'),
  readNotification: (id) => patch(`/notifications/${id}/read`),
}

export const WORKFORCE_CALLS = Object.keys(workforceApi)
