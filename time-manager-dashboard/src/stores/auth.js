import { reactive } from 'vue'
import { announceSessionChange } from '../utils/sessionEvents'
import * as authService from '../services/authService'
import { AUTH_USE_MOCK, getSession, loginAccount, logoutAccount } from '../services/organizationService'

// The JWT lives in an HttpOnly cookie: page scripts can never read it. The
// front-end only keeps the CSRF token returned at login, in memory and in
// sessionStorage. A new tab obtains its own copy from /auth/session. On its
// own the token is useless: the API also needs the cookie, that only this
// browser sends.
const CSRF_KEY = 'tm-csrf'
let sessionRevision = 0
let pendingSession = null
let logoutPending = false

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
  sessionRevision += 1
  if (session.csrf_token) writeCsrf(session.csrf_token)
  auth.organization = session.organization || null
  auth.user = { ...session.user, role: session.user.role === 'admin' ? 'administrator' : session.user.role }
  auth.checked = true
  return auth.user
}

// Keep real organization context separate from the local demo workspace.
export function startOrganizationSession(session) {
  if (!AUTH_USE_MOCK) {
    auth.organizationSession = null
    const user = startSession(session)
    announceSessionChange()
    return user
  }
  writeCsrf(null)
  auth.organization = session.organization
  auth.organizationSession = session
  auth.user = { ...session.user, role: session.role === 'admin' ? 'administrator' : session.role }
  auth.checked = true
  return auth.user
}

export async function login(email, password) {
  sessionRevision += 1
  const user = startOrganizationSession(await loginAccount({ email, password }))
  return user
}

export async function register(attrs) {
  void attrs
  throw new Error('L’inscription directe est désactivée. Envoyez une demande pour rejoindre Gotham City.')
}

// Preserve the OTP service used by the legacy registration component without
// reopening direct registration in the Gotham admission flow.
export async function verifyEmail(email, code) {
  return startSession(await authService.verifyEmail(email, code))
}

export async function resendVerification(email) {
  return authService.resendVerification(email)
}

// Restore from the shared HttpOnly cookie even when this tab has no CSRF yet.
// Concurrent callers share one read; a stale read cannot undo login/logout.
export async function fetchMe({ throwOnFailure = false } = {}) {
  if (AUTH_USE_MOCK) {
    try { return startOrganizationSession(await getSession()) }
    catch { clearSession(); return null }
  }
  if (logoutPending) return null
  const revision = sessionRevision
  if (!pendingSession || pendingSession.revision !== revision) {
    pendingSession = { revision, promise: getSession() }
  }
  const pending = pendingSession
  try {
    const session = await pending.promise
    if (revision === sessionRevision) startSession(session)
  } catch (error) {
    if (revision === sessionRevision) {
      if (error.status === 401) clearSession()
      else if (throwOnFailure) throw error
    }
  } finally {
    if (pendingSession === pending) pendingSession = null
  }
  auth.checked = true
  return auth.user
}

// An unauthorized action is retried only if the API confirms the same user.
export async function restoreForRequest(expectedUserId) {
  await fetchMe({ throwOnFailure: true })
  if (!auth.user) return 'expired'
  return auth.user.id === expectedUserId ? 'restored' : 'changed'
}

export async function logout() {
  logoutPending = true
  const revision = ++sessionRevision
  try { await logoutAccount() }
  finally {
    logoutPending = false
    if (revision === sessionRevision) clearSession()
    if (!AUTH_USE_MOCK) announceSessionChange()
  }
}

// Forgets the session locally (logout, or a 401 from the API).
export function clearSession() {
  sessionRevision += 1
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
