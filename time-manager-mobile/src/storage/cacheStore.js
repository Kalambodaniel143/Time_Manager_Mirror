import { read, write } from './database.js'

// Dernières données reçues du serveur, rangées par utilisateur.
const key = (userId, name) => `${userId}:cache:${name}`

export function readCache(userId, name) {
  return read(key(userId, name))
}

export function writeCache(userId, name, data) {
  const entry = { data, updatedAt: new Date().toISOString() }
  write(key(userId, name), entry)
  return entry
}
