import { USE_MOCK } from '../config'
import { buildQuery, mocked, request } from './http'
import {
  mockCreateUser,
  mockDeleteUser,
  mockGetUser,
  mockListUsers,
  mockUpdateUser,
} from '../mocks/users'

export function listUsers(filters = {}) {
  if (USE_MOCK) return mocked(() => mockListUsers(filters))

  return request(`/users${buildQuery(filters)}`)
}

export function getUser(id) {
  if (USE_MOCK) return mocked(() => mockGetUser(id))

  return request(`/users/${id}`)
}

export function createUser(attrs) {
  if (USE_MOCK) return mocked(() => mockCreateUser(attrs))

  return request('/users', { method: 'POST', body: JSON.stringify({ user: attrs }) })
}

export function updateUser(id, attrs) {
  if (USE_MOCK) return mocked(() => mockUpdateUser(id, attrs))

  return request(`/users/${id}`, { method: 'PUT', body: JSON.stringify({ user: attrs }) })
}

export function deleteUser(id) {
  if (USE_MOCK) return mocked(() => mockDeleteUser(id))

  return request(`/users/${id}`, { method: 'DELETE' })
}
