import { reactive } from 'vue'
import * as authService from '../services/authService'
import { AUTH_USE_MOCK, getSession, logoutAccount } from '../services/organizationService'

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
  organizationSession: null,
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

// Organization demos use the same role checks as backend users.
export function startOrganizationSession(session) {
  writeCsrf(null)
  auth.organizationSession = session
  auth.user = { ...session.user, role: session.role === 'admin' ? 'administrator' : session.role }
  auth.checked = true
  return auth.user
}

export async function login(email, password) {
  return startSession(await authService.login(email, password))
}

export async function register(attrs) {
  return authService.register(attrs)
}

export async function verifyEmail(email, code) {
  return startSession(await authService.verifyEmail(email, code))
}

export async function resendVerification(email) {
  return authService.resendVerification(email)
}

// Asks the API who is logged in. Without a CSRF token there is no usable
// session, so the call is skipped.
export async function fetchMe() {
  if (AUTH_USE_MOCK) {
    try { return startOrganizationSession(await getSession()) }
    catch { clearSession(); return null }
  }

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
    if (auth.organizationSession) await logoutAccount()
    else await authService.logout()
  } finally {
    clearSession()
  }
}

// Forgets the session locally (logout, or a 401 from the API).
export function clearSession() {
  auth.organizationSession = null
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
