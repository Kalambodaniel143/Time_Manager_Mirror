import { reactive } from 'vue'
import { AUTH_USE_MOCK, getSession, loginAccount, logoutAccount } from '../services/organizationService'

// The JWT lives in an HttpOnly cookie: page scripts can never read it. The
// front-end only keeps the CSRF token returned at login, in memory and in
// sessionStorage (so it survives a page refresh, but not a closed tab). On its
// own the token is useless: the API also needs the cookie, that only this
// browser sends.
const CSRF_KEY = 'tm-csrf'

export const ROLE_LABELS = {
  employee: 'Employé',
  manager: 'Manager',
  administrator: 'Super administrateur',
}

export const auth = reactive({
  user: null,
  organizationSession: null,
  organization: null,
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
  if (session.csrf_token) writeCsrf(session.csrf_token)
  auth.organization = session.organization || null
  auth.user = { ...session.user, role: session.user.role === 'admin' ? 'administrator' : session.user.role }
  auth.checked = true
  return auth.user
}

// Keep real organization context separate from the local demo workspace.
export function startOrganizationSession(session) {
  if (!AUTH_USE_MOCK) { auth.organizationSession = null; return startSession(session) }
  writeCsrf(null)
  auth.organization = session.organization
  auth.organizationSession = session
  auth.user = { ...session.user, role: session.role === 'admin' ? 'administrator' : session.role }
  auth.checked = true
  return auth.user
}

export async function login(email, password) {
  return startOrganizationSession(await loginAccount({ email, password }))
}

export async function register(attrs) {
  void attrs
  throw new Error('L’inscription directe est désactivée. Envoyez une demande pour rejoindre Gotham City.')
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
    startSession(await getSession())
  } catch {
    clearSession()
  }

  auth.checked = true
  return auth.user
}

export async function logout() {
  try {
    await logoutAccount()
  } finally {
    clearSession()
  }
}

// Forgets the session locally (logout, or a 401 from the API).
export function clearSession() {
  auth.organizationSession = null
  auth.organization = null
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
