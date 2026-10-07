import { auth } from '../stores/auth'
import { workPeriods, workCreatePeriod, workUpdatePeriod, workDeletePeriod } from '../mocks/organizationWork'
import { USE_MOCK } from '../config'
import { buildQuery, mocked, request } from './http'
import {
  mockCreateWorkingTime,
  mockDeleteWorkingTime,
  mockGetWorkingTime,
  mockListWorkingTimes,
  mockUpdateWorkingTime,
} from '../mocks/workingTimes'

export function getWorkingTimes(userId, filters = {}) {
  if (auth.organizationSession) return Promise.resolve().then(() => workPeriods(userId, filters))
  if (USE_MOCK) return mocked(() => mockListWorkingTimes(Number(userId), filters))

  return request(`/workingtime/${userId}${buildQuery(filters)}`)
}

export function getWorkingTime(userId, id) {
  if (auth.organizationSession) return Promise.resolve().then(() => workPeriods(userId).find(period => period.id === Number(id)) || null)
  if (USE_MOCK) return mocked(() => mockGetWorkingTime(Number(userId), id))

  return request(`/workingtime/${userId}/${id}`)
}

export function createWorkingTime(userId, attrs) {
  if (auth.organizationSession) return Promise.resolve().then(() => workCreatePeriod(userId, attrs))
  if (USE_MOCK) return mocked(() => mockCreateWorkingTime(Number(userId), attrs))

  return request(`/workingtime/${userId}`, {
    method: 'POST',
    body: JSON.stringify({ workingtime: attrs }),
  })
}

export function updateWorkingTime(id, attrs) {
  if (auth.organizationSession) return Promise.resolve().then(() => workUpdatePeriod(id, attrs))
  if (USE_MOCK) return mocked(() => mockUpdateWorkingTime(id, attrs))

  return request(`/workingtime/${id}`, {
    method: 'PUT',
    body: JSON.stringify({ workingtime: attrs }),
  })
}

export function deleteWorkingTime(id) {
  if (auth.organizationSession) return Promise.resolve().then(() => workDeletePeriod(id))
  if (USE_MOCK) return mocked(() => mockDeleteWorkingTime(id))

  return request(`/workingtime/${id}`, { method: 'DELETE' })
}
