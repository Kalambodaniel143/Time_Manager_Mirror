// Front-only workspace for organization demos. Its data never reaches the API.
import { mockSession, mockWorkMembers } from './organizationAuth.js'
import { clockDate } from '../utils/missingDeparture'
import { formatClockDate } from '../utils/clockDate'

function failure(message) { throw new Error(message) }
function workspace() {
  const session = mockSession()
  const key = `tm-work-demo:${session.organization.id}`
  const db = JSON.parse(localStorage.getItem(key) || '{"clocks":[],"periods":[],"corrections":[]}')
  return { session, key, db }
}
function save(key, db) { localStorage.setItem(key, JSON.stringify(db)) }
function id(items) { return Math.max(0, ...items.map(item => item.id)) + 1 }
function allow(session, userId, edit = false) {
  const member = mockWorkMembers().find(user => user.id === Number(userId))
  if (!member || (edit && (session.role === 'employee' || (session.role === 'manager' && session.user.id === Number(userId))))) failure('Cette action ne fait pas partie de vos droits.')
}
export function workMembers() { return mockWorkMembers() }
export function workClocks(userId) {
  const { session, db } = workspace(); allow(session, userId)
  return db.clocks.filter(clock => clock.user_id === Number(userId)).map(clock => ({ ...clock }))
}
export function workPeriods(userId, filters = {}) {
  const { session, db } = workspace(); allow(session, userId)
  return db.periods.filter(period => period.user_id === Number(userId) && (!filters.start || period.start >= filters.start) && (!filters.end || period.end <= filters.end)).map(period => ({ ...period }))
}
export function workClock(userId, attrs, expectedId) {
  const { session, key, db } = workspace()
  if (session.user.id !== Number(userId)) failure('Vous pouvez pointer uniquement pour vous-même.')
  const previous = db.clocks.filter(clock => clock.user_id === Number(userId)).at(-1)
  const kind = attrs.kind || (attrs.status ? 'arrival' : 'departure')
  const allowed = { arrival: ['pause', 'departure'], resume: ['pause', 'departure'], pause: ['resume', 'departure'], departure: ['arrival'] }
  if (!(previous ? allowed[previous.kind] : ['arrival']).includes(kind)) failure('Les pointages ont changé. Actualisez avant de réessayer.')
  const time = formatClockDate(attrs.time)
  if (clockDate(time) > new Date()) failure('Un pointage ne peut pas être dans le futur.')
  if (attrs.status !== ['arrival', 'resume'].includes(kind)) failure('Le statut ne correspond pas au type de pointage.')
  if (!time || (previous && time <= previous.time)) failure('L’heure doit suivre le dernier pointage.')
  if (expectedId !== undefined && (!previous || previous.id !== Number(expectedId))) failure('Les pointages ont changé. Actualisez avant de réessayer.')
  const created = { id: id(db.clocks), user_id: Number(userId), time, kind, status: ['arrival', 'resume'].includes(kind) }
  if (previous && ['arrival', 'resume'].includes(previous.kind)) db.periods.push({ id: id(db.periods), user_id: Number(userId), start: previous.time, end: time })
  db.clocks.push(created); save(key, db); return created
}
export function workCreatePeriod(userId, attrs) {
  const { session, key, db } = workspace(); allow(session, userId, true)
  if (!attrs.start || !attrs.end || clockDate(attrs.end) <= clockDate(attrs.start) || clockDate(attrs.end) > new Date()) failure('Vérifiez les horaires réels, sans date future.')
  const created = { id: id(db.periods), user_id: Number(userId), start: attrs.start, end: attrs.end }; db.periods.push(created); save(key, db); return created
}
export function workUpdatePeriod(periodId, attrs) {
  const { session, key, db } = workspace(); const period = db.periods.find(item => item.id === Number(periodId))
  if (!period) failure('Période introuvable.'); allow(session, period.user_id, true)
  if (!attrs.start || !attrs.end || clockDate(attrs.end) <= clockDate(attrs.start) || clockDate(attrs.end) > new Date()) failure('Vérifiez les horaires réels, sans date future.')
  Object.assign(period, { start: attrs.start, end: attrs.end }); save(key, db); return period
}
export function workDeletePeriod(periodId) {
  const { session, key, db } = workspace(); const period = db.periods.find(item => item.id === Number(periodId))
  if (!period) failure('Période introuvable.'); allow(session, period.user_id, true)
  db.periods = db.periods.filter(item => item.id !== Number(periodId)); save(key, db)
}
export function workCorrections(userId) {
  const { session, db } = workspace()
  return db.corrections.filter(item => (session.role !== 'employee' || item.user_id === session.user.id) && (!userId || item.user_id === Number(userId)))
}
export function workRequestCorrection(periodId, attrs) {
  const { session, key, db } = workspace(); const period = db.periods.find(item => item.id === Number(periodId))
  if (!period || period.user_id !== session.user.id) failure('Vous pouvez proposer une correction uniquement sur vos heures.')
  if (db.corrections.some(item => item.period_id === period.id && item.status === 'pending')) failure('Une demande est déjà en attente pour cette période.')
  if (!attrs.reason?.trim() || attrs.reason.length > 500 || !attrs.start || !attrs.end || clockDate(attrs.end) <= clockDate(attrs.start) || clockDate(attrs.end) > new Date()) failure('Vérifiez les horaires et indiquez un motif.')
  const created = { id: id(db.corrections), period_id: period.id, user_id: period.user_id, username: session.user.username, before: { start: period.start, end: period.end }, proposal: { start: attrs.start, end: attrs.end }, reason: attrs.reason.trim(), status: 'pending', created_at: new Date().toISOString() }
  db.corrections.push(created); save(key, db); return created
}
export function workReviewCorrection(requestId, decision, reason) {
  const { session, key, db } = workspace(); const correction = db.corrections.find(item => item.id === Number(requestId))
  if (!correction || correction.status !== 'pending') failure('Cette demande a déjà été traitée.')
  if (session.user.id === correction.user_id) failure('Vous ne pouvez pas approuver votre propre correction.')
  allow(session, correction.user_id, true)
  const period = db.periods.find(item => item.id === correction.period_id)
  if (!period || period.start !== correction.before.start || period.end !== correction.before.end) failure('Les horaires ont changé. Une nouvelle demande est nécessaire.')
  if (!['approved', 'rejected'].includes(decision)) failure('Décision invalide.')
  if (decision === 'rejected' && !reason?.trim()) failure('Indiquez le motif du refus.')
  if (decision === 'approved') Object.assign(period, correction.proposal)
  Object.assign(correction, { status: decision, reviewed_at: new Date().toISOString(), reviewed_by: session.user.username, review_reason: reason?.trim() || '' })
  save(key, db); return correction
}
