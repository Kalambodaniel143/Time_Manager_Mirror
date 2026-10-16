import { USE_MOCK } from '../config'
import { auth } from '../stores/auth'
import { buildQuery, mocked, request } from './http'
import {
  mockCreateUser,
  mockDeleteUser,
  mockGetUser,
  mockListUsers,
  mockUpdateUser,
} from '../mocks/users'

function standaloneMock() { return USE_MOCK && !auth.user }

export function listUsers(filters = {}) {
  if (standaloneMock()) return mocked(() => mockListUsers(filters))

  return request(`/users${buildQuery(filters)}`)
}

export function getUser(id) {
  if (standaloneMock()) return mocked(() => mockGetUser(id))

  return request(`/users/${id}`)
}

export function createUser(attrs) {
  if (standaloneMock()) return mocked(() => mockCreateUser(attrs))

  return request('/users', { method: 'POST', body: JSON.stringify({ user: attrs }) })
}

export function updateUser(id, attrs) {
  if (standaloneMock()) return mocked(() => mockUpdateUser(id, attrs))

  return request(`/users/${id}`, { method: 'PUT', body: JSON.stringify({ user: attrs }) })
}

export function deleteUser(id) {
  if (standaloneMock()) return mocked(() => mockDeleteUser(id))

  return request(`/users/${id}`, { method: 'DELETE' })
}
