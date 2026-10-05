// Simulation locale du futur backend. Ne jamais utiliser comme authentification de production.
import { normalizeName, organizationError, passwordError, profileErrors, profilePayload } from '../utils/registration.js'

const STATE_KEY = 'tm-auth-demo-v1'
const SESSION_KEY = 'tm-auth-demo-current'

function fail(status, detail, fields = {}) {
  const error = new Error(detail)
  error.status = status
  error.payload = { errors: { detail, ...fields } }
  throw error
}

function state() {
  try {
    return JSON.parse(localStorage.getItem(STATE_KEY)) || { organizations: [], users: [], requests: [] }
  } catch {
    fail(503, 'Le stockage local est indisponible. Autorisez-le pour utiliser la simulation.')
  }
}

function save(value) {
  try { localStorage.setItem(STATE_KEY, JSON.stringify(value)) }
  catch { fail(503, 'Impossible d’enregistrer les données dans ce navigateur.') }
}

function cleanProfile(profile, personalDetails = true) {
  const fields = profileErrors(profile, personalDetails)
  if (Object.keys(fields).length) fail(422, 'Vérifiez les champs du formulaire.', fields)
  return profilePayload(profile, personalDetails)
}

function publicUser(user) {
  const { password_hash: _hash, password_salt: _salt, ...result } = user
  return result
}

async function digest(password, salt) {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(password), 'PBKDF2', false, ['deriveBits'])
  const bits = await crypto.subtle.deriveBits({ name: 'PBKDF2', salt: new TextEncoder().encode(salt), iterations: 120000, hash: 'SHA-256' }, key, 256)
  return Array.from(new Uint8Array(bits), (byte) => byte.toString(16).padStart(2, '0')).join('')
}

async function passwordRecord(password) {
  const message = passwordError(password)
  if (message) fail(422, message, { password: [message] })
  const salt = crypto.randomUUID()
  return { password_salt: salt, password_hash: await digest(password, salt) }
}

function sessionFor(db, id) {
  const user = db.users.find((item) => item.id === id)
  if (!user) fail(401, 'Connectez-vous pour continuer.')
  const organization = db.organizations.find((item) => item.id === user.organization_id)
  if (!organization) fail(401, 'Cette organisation est indisponible.')
  return { user: publicUser(user), organization, role: user.role }
}

function current(db) {
  return sessionFor(db, Number(localStorage.getItem(SESSION_KEY)))
}

function admin(db, organizationId) {
  const session = current(db)
  if (session.role !== 'admin' || session.organization.id !== organizationId) fail(403, 'Cette action est réservée à l’admin de cette organisation.')
  return session
}

function nextId(db) {
  return Math.max(10000, ...db.users.map((user) => user.id)) + 1
}

function requestView(request) {
  const { reference: _reference, ...view } = request
  return view
}

export async function mockCreateOrganization({ name, profile, password }) {
  const clean = cleanProfile(profile, false)
  const message = organizationError(name)
  if (message) fail(422, message, { name: [message] })
  const record = await passwordRecord(password)
  const db = state()
  if (db.organizations.some((org) => normalizeName(org.name) === normalizeName(name))) fail(409, 'Une organisation porte déjà ce nom.', { name: ['Ce nom est déjà utilisé.'] })
  if (db.users.some((user) => user.email === clean.email)) fail(409, 'Cette adresse email possède déjà un compte.', { email: ['Cette adresse est déjà utilisée.'] })
  const organization = { id: crypto.randomUUID(), name: name.trim().replace(/\s+/g, ' '), created_at: new Date().toISOString() }
  const user = { ...clean, ...record, id: nextId(db), username: clean.email, organization_id: organization.id, role: 'admin', created_at: new Date().toISOString() }
  db.organizations.push(organization)
  db.users.push(user)
  save(db)
  localStorage.setItem(SESSION_KEY, String(user.id))
  return sessionFor(db, user.id)
}

export async function mockLogin({ email, password }) {
  const db = state()
  const user = db.users.find((item) => item.email === email.trim().toLowerCase())
  if (!user || await digest(password, user.password_salt) !== user.password_hash) fail(401, 'Email ou mot de passe incorrect.')
  localStorage.setItem(SESSION_KEY, String(user.id))
  return sessionFor(db, user.id)
}

export function mockSession() { return current(state()) }
export function mockLogout() { localStorage.removeItem(SESSION_KEY); return null }

export function mockLookupOrganization(name) {
  const organization = state().organizations.find((item) => normalizeName(item.name) === normalizeName(name))
  if (!organization) fail(404, 'Cette organisation n’existe pas. Vérifiez son nom auprès de votre admin.')
  return { id: organization.id, name: organization.name }
}

export function mockJoinOrganization({ organization_id, profile }) {
  const clean = cleanProfile(profile)
  const db = state()
  const organization = db.organizations.find((item) => item.id === organization_id)
  if (!organization) fail(404, 'Cette organisation n’existe pas.')
  if (db.users.some((user) => user.email === clean.email)) fail(409, 'Cette adresse email possède déjà un compte. Connectez-vous.')
  if (db.requests.some((request) => request.organization_id === organization_id && request.profile.email === clean.email && request.status === 'pending')) fail(409, 'Une demande est déjà en attente pour cette adresse email.')
  const request = { id: crypto.randomUUID(), reference: crypto.randomUUID(), organization_id, organization_name: organization.name, profile: clean, status: 'pending', created_at: new Date().toISOString(), reviewed_at: null, rejection_reason: null }
  db.requests.push(request)
  save(db)
  return { id: request.id, reference: request.reference, organization_name: organization.name, status: request.status }
}

export function mockRequestStatus(reference) {
  const request = state().requests.find((item) => item.reference === reference)
  if (!request) fail(404, 'Référence de demande introuvable.')
  return { id: request.id, reference, organization_name: request.organization_name, status: request.status, rejection_reason: request.rejection_reason }
}

export function mockListRequests(organizationId) {
  const db = state()
  admin(db, organizationId)
  return db.requests.filter((item) => item.organization_id === organizationId).map(requestView)
}

export async function mockApproveRequest(organizationId, id, password) {
  admin(state(), organizationId)
  const record = await passwordRecord(password)
  const db = state()
  const reviewer = admin(db, organizationId)
  const request = db.requests.find((item) => item.id === id && item.organization_id === organizationId)
  if (!request) fail(404, 'Demande introuvable.')
  if (request.status !== 'pending') fail(409, 'Cette demande a déjà été traitée.')
  if (db.users.some((user) => user.email === request.profile.email)) fail(409, 'Cette adresse possède déjà un compte.')
  const user = { ...request.profile, ...record, id: nextId(db), username: request.profile.email, organization_id: organizationId, role: 'employee', created_at: new Date().toISOString() }
  db.users.push(user)
  request.status = 'approved'
  request.reviewed_at = new Date().toISOString()
  request.reviewed_by = reviewer.user.id
  save(db)
  return { request: requestView(request), user: publicUser(user) }
}

export function mockRejectRequest(organizationId, id, reason) {
  const db = state()
  const reviewer = admin(db, organizationId)
  const request = db.requests.find((item) => item.id === id && item.organization_id === organizationId)
  if (!request) fail(404, 'Demande introuvable.')
  if (request.status !== 'pending') fail(409, 'Cette demande a déjà été traitée.')
  if (!reason.trim() || reason.length > 500) fail(422, 'Indiquez un motif de refus (500 caractères maximum).')
  Object.assign(request, { status: 'rejected', rejection_reason: reason.trim(), reviewed_at: new Date().toISOString(), reviewed_by: reviewer.user.id })
  save(db)
  return requestView(request)
}

export function mockListMembers(organizationId) {
  const db = state()
  admin(db, organizationId)
  return db.users.filter((user) => user.organization_id === organizationId).map(publicUser)
}

export function mockSetRole(organizationId, userId, role) {
  const db = state()
  admin(db, organizationId)
  const user = db.users.find((item) => item.id === userId && item.organization_id === organizationId)
  if (!user) fail(404, 'Membre introuvable.')
  if (user.role === 'admin' || !['employee', 'manager'].includes(role)) fail(403, 'Seuls les rôles employé et manager peuvent être modifiés ici.')
  user.role = role
  save(db)
  return publicUser(user)
}
