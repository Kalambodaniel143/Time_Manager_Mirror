import { read, write } from '@/storage/database.js'
import { fail } from './db.js'

export const ownerOf = (periodId) => Math.floor(Number(periodId) / 100000)

// Corrections d'heures du faux serveur, rangées par agent :
// { added: [période], removed: [id], changed: { id: { start, end } } }
const key = (userId) => `mock:wt:${userId}`
const edits = (userId) => read(key(userId), { added: [], removed: [], changed: {} })
const toServer = (iso) => new Date(iso).toISOString().slice(0, 19).replace('T', ' ')

function checked({ start, end }) {
  if (!start || !end || new Date(end) <= new Date(start)) throw fail(422, 'end must be after start')
  return { start: toServer(start), end: toServer(end) }
}

// Applique les corrections aux périodes calculées depuis les pointages.
export function applyEdits(userId, periods) {
  const e = edits(userId)
  return [...periods, ...e.added]
    .filter((p) => !e.removed.includes(p.id))
    .map((p) => ({ ...p, ...e.changed[p.id] }))
}

export function addPeriod(userId, period) {
  const e = edits(userId)
  const created = { id: Number(userId) * 100000 + 50000 + e.added.length, user_id: Number(userId), ...checked(period) }
  write(key(userId), { ...e, added: [...e.added, created] })
  return created
}

export function changePeriod(userId, id, period) {
  const e = edits(userId)
  write(key(userId), { ...e, changed: { ...e.changed, [id]: checked(period) } })
  return { id, user_id: Number(userId), ...checked(period) }
}

export function removePeriod(userId, id) {
  const e = edits(userId)
  write(key(userId), { ...e, removed: [...e.removed, Number(id)] })
}
