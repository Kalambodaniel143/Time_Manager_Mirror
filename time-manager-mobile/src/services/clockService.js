import { app } from './appState.js'
import { api } from './source.js'
import { isUnreachable } from './network.js'
import { readCache, writeCache } from '@/storage/cacheStore.js'
import { getPointages } from './dataService.js'
import { syncNow, refreshCounts } from './syncService.js'
import { enqueueAction, listActions } from '@/storage/outboxStore.js'
import { summarize } from '@/ui/clockState.js'
import { toApiTime, toUtcIso } from '@/ui/dates.js'
import { serverNow } from './serverClock.js'
import { vibrate } from '@/native/device.js'

// État du pointage = pointages connus du serveur + actions encore sur le téléphone.
export async function getClockState() {
  const server = await getPointages().catch(() => ({ data: [], stale: true, updatedAt: null }))
  // Ordre du serveur (déjà trié), puis les actions pas encore envoyées (plus récentes).
  const serverEvents = server.data.map((c) => ({ ...c, time: toUtcIso(c.time) }))
  const known = (a) => serverEvents.some((c) => c.kind === a.kind && Date.parse(c.time) === Date.parse(a.time))
  const local = listActions(app.user.id).filter((a) => a.status === 'pending' && !known(a))
  const events = [...serverEvents, ...local.map((a) => ({ ...a, local: true }))]
  return { ...summarize(events), stale: server.stale, updatedAt: server.updatedAt }
}

// 1. écrire sur le téléphone (heure réelle) · 2. confirmer · 3. envoyer si possible.
export function recordClock(kind, time = toApiTime(serverNow())) {
  const action = enqueueAction(app.user.id, kind, time)
  vibrate()
  refreshCounts()
  syncNow()
  return action
}

// Départ oublié : en ligne, route dédiée du serveur (POST /clocks/:id/:clockID/complete),
// qui vérifie que le service n'a pas changé. Hors ligne, ou si le dernier pointage n'est
// pas encore sur le serveur : départ normal, mis en file d'attente.
export async function completeDeparture(time, lastClock) {
  if (!lastClock?.id || lastClock.local) return recordClock('departure', time)
  try {
    const clock = await api.completeClock(app.user.id, lastClock.id, time)
    const cached = readCache(app.user.id, `clocks:${app.user.id}`)?.data ?? []
    writeCache(app.user.id, `clocks:${app.user.id}`, [...cached, clock])
    vibrate()
    return clock
  } catch (error) {
    if (isUnreachable(error)) return recordClock('departure', time)
    throw error
  }
}
