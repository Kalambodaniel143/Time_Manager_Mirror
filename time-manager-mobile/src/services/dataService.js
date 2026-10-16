import { api } from './source.js'
import { app } from './appState.js'
import { handleError, isUnreachable, reportServer } from './network.js'
import { readCache, writeCache } from '@/storage/cacheStore.js'

// Lecture avec repli : le serveur si possible, sinon les dernières données du téléphone.
// Retourne { data, updatedAt, stale } ; stale = true si les données peuvent être anciennes.
export async function load(name, fetcher) {
  const userId = app.user.id
  try {
    const data = await fetcher()
    reportServer(true)
    return { ...writeCache(userId, name, data), stale: false }
  } catch (error) {
    handleError(error)
    const cached = readCache(userId, name)
    if (cached && (isUnreachable(error) || !error.kind)) return { ...cached, stale: true }
    throw error
  }
}

const me = () => app.user.id

export const getUser = (userId = me()) => load(`user:${userId}`, () => api.getUser(userId))
export const getPointages = (userId = me()) => load(`clocks:${userId}`, () => api.getClocks(userId))
export const getMesHeures = (userId = me()) => load(`hours:${userId}`, () => api.getWorkingTimes(userId))
export const getTeams = () => load('teams', () => api.getTeams())
export const getUsers = () => load('users', () => api.getUsers())
