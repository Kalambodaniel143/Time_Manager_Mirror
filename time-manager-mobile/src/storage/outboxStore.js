import { read, write } from './database.js'

// File des pointages à envoyer : une file par utilisateur, dans l'ordre des clics.
// status : 'pending' (à envoyer) · 'synced' (confirmé) · 'conflict' (refusé, à vérifier)
const key = (userId) => `${userId}:outbox`
const newId = () => crypto.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`

export function listActions(userId) {
  return read(key(userId), [])
}

export function enqueueAction(userId, kind, time) {
  const action = { id: newId(), userId, kind, time, status: 'pending', attempts: 0, error: null }
  write(key(userId), [...listActions(userId), action])
  return action
}

export function updateAction(userId, id, changes) {
  write(key(userId), listActions(userId).map((a) => (a.id === id ? { ...a, ...changes } : a)))
}

export function removeAction(userId, id) {
  write(key(userId), listActions(userId).filter((a) => a.id !== id))
}

export function pruneSynced(userId) {
  write(key(userId), listActions(userId).filter((a) => a.status !== 'synced'))
}
