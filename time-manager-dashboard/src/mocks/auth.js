import { PERSONAS } from './org'

// Demo mode only (npm run dev:demo): no API, one account per persona, any password.
const KEY = 'tm-mock-user'
const ROLES = { employee: 'employee', manager: 'manager', admin: 'administrator' }

function toUser(persona, id) {
  return { id, username: persona.username, email: persona.email, role: ROLES[persona.role] }
}

function remember(user) {
  sessionStorage.setItem(KEY, JSON.stringify(user))
  return { csrf_token: 'demo', user }
}

export function mockLogin(email) {
  const personas = Object.values(PERSONAS)
  const index = personas.findIndex((persona) => persona.email === String(email).toLowerCase())
  if (index === -1) throw new Error(`Comptes de démo : ${personas.map((persona) => persona.email).join(', ')}`)

  return remember(toUser(personas[index], index + 1))
}

export function mockRegister(attrs) {
  return remember({ id: 99, username: attrs.username, email: attrs.email, role: 'employee' })
}

export function mockMe() {
  const raw = sessionStorage.getItem(KEY)
  if (!raw) throw new Error('Not logged in')
  return JSON.parse(raw)
}

export function mockLogout() {
  sessionStorage.removeItem(KEY)
  return null
}
