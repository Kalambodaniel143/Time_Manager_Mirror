import { reactive } from 'vue'
import * as authService from '../services/authService'

// The JWT lives in an HttpOnly cookie: page scripts can never read it. The
// front-end only keeps the CSRF token returned at login, in memory and in
// sessionStorage (so it survives a page refresh, but not a closed tab). On its
// own the token is useless: the API also needs the cookie, that only this
// browser sends.
const CSRF_KEY = 'tm-csrf'

export const ROLE_LABELS = {
  employee: 'Employé',
  manager: 'Manager',
  administrator: 'Administrateur',
}

export const auth = reactive({
  user: null,
  csrfToken: readCsrf(),
  // True once we know whether a session exists (GET /auth/me answered).
  checked: false,
})

function readCsrf() {
  try {
    return sessionStorage.getItem(CSRF_KEY)
  } catch {
    return null
  }
}

function writeCsrf(token) {
  auth.csrfToken = token
  try {
    if (token) sessionStorage.setItem(CSRF_KEY, token)
    else sessionStorage.removeItem(CSRF_KEY)
  } catch {
    return
  }
}

function startSession(session) {
  writeCsrf(session.csrf_token)
  auth.user = session.user
  auth.checked = true
  return session.user
}

export async function login(email, password) {
  return startSession(await authService.login(email, password))
}

export async function register(attrs) {
  return startSession(await authService.register(attrs))
}

// Asks the API who is logged in. Without a CSRF token there is no usable
// session, so the call is skipped.
export async function fetchMe() {
  if (!auth.csrfToken) {
    auth.checked = true
    return null
  }

  try {
    auth.user = await authService.me()
  } catch {
    clearSession()
  }

  auth.checked = true
  return auth.user
}

export async function logout() {
  try {
    await authService.logout()
  } finally {
    clearSession()
  }
}

// Forgets the session locally (logout, or a 401 from the API).
export function clearSession() {
  auth.user = null
  auth.checked = true
  writeCsrf(null)
}

export function setUser(user) {
  auth.user = user
}

export function hasRole(...roles) {
  return Boolean(auth.user) && roles.includes(auth.user.role)
}

export function isSelf(userId) {
  return Boolean(auth.user) && Number(userId) === auth.user.id
}

// Interface hints only: the API checks every request again and has the final
// word (a manager only edits the hours of the teams they manage).
export function canEditHours(userId) {
  if (hasRole('administrator')) return true
  return hasRole('manager') && !isSelf(userId)
}
