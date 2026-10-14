import { t } from '@/i18n/index.js'
import { api } from './source.js'
import { app } from './appState.js'
import { handleError, reportServer } from './network.js'
import { listActions, updateAction, pruneSynced } from '@/storage/outboxStore.js'
import { readCache, writeCache } from '@/storage/cacheStore.js'
import { onSyncOpportunity, onConnectionLost } from '@/native/lifecycle.js'
import { notAfterServerNow } from './serverClock.js'
import { clockRefusal, isFutureRefusal } from '@/ui/clockErrors.js'
import { toUtcIso } from '@/ui/dates.js'

// Ces erreurs ne disent rien de l'action : on la garde et on réessaiera.
const RETRY_LATER = ['network', 'timeout', 'server', 'cancelled', 'unauthorized']
const sameClock = (clock, action) => clock.kind === action.kind && Date.parse(toUtcIso(clock.time)) === Date.parse(action.time)
let running = null // envoi en cours (promesse partagée)

export function refreshCounts() {
  const actions = app.user ? listActions(app.user.id) : []
  app.pending = actions.filter((a) => a.status === 'pending').length
  app.conflicts = actions.filter((a) => a.status === 'conflict').length
}

// Envoie les actions du compte connecté, une par une, dans l'ordre.
// Un seul envoi à la fois : un second appel attend le premier.
export function syncNow() {
  if (!running) running = send().finally(() => { running = null })
  return running
}

async function send() {
  const user = app.user
  if (!user) return
  app.syncing = true
  const before = app.pending
  try {
    pruneSynced(user.id)
    let serverClocks = null
    for (const action of listActions(user.id).filter((a) => a.status === 'pending')) {
      if (app.user?.id !== user.id) break
      // Déjà tenté : la réponse a pu se perdre. Le serveur l'a-t-il déjà ? (anti-doublon)
      if (action.attempts > 0) {
        serverClocks ??= await api.getClocks(user.id)
        const existing = serverClocks.find((c) => sameClock(c, action))
        if (existing) { confirm(user.id, action, existing); continue }
      }
      updateAction(user.id, action.id, { attempts: action.attempts + 1 })
      try {
        confirm(user.id, action, await sendClock(user.id, action))
      } catch (error) {
        if (RETRY_LATER.includes(error.kind) || !error.kind) throw error
        updateAction(user.id, action.id, { status: 'conflict', error: clockRefusal(error) })
        app.lastRefusal = { kind: action.kind, reason: clockRefusal(error) }
      }
    }
    reportServer(true)
  } catch (error) {
    handleError(error)
  } finally {
    app.syncing = false
    refreshCounts()
    if (before > 0 && app.pending === 0) showNotice(t('Synchronisation terminée'))
  }
}

// Jamais après l'heure du serveur (heure corrigée gardée pour l'anti-doublon).
// Si l'horloge du téléphone a sauté entre-temps, le refus « dans le futur » apporte
// l'heure du serveur : on réessaie une fois avec l'heure corrigée.
async function sendClock(userId, action) {
  for (let attempt = 1; ; attempt++) {
    const time = notAfterServerNow(action.time)
    updateAction(userId, action.id, { time })
    try {
      return await api.createClock(userId, { ...action, time })
    } catch (error) {
      if (attempt > 1 || !isFutureRefusal(error)) throw error
    }
  }
}

function showNotice(text) {
  app.notice = text
  setTimeout(() => { app.notice = '' }, 4000)
}

function confirm(userId, action, clock) {
  updateAction(userId, action.id, { status: 'synced' })
  const cached = readCache(userId, `clocks:${userId}`)?.data ?? []
  writeCache(userId, `clocks:${userId}`, [...cached.filter((c) => c.id !== clock.id), clock])
}

// Synchronisation automatique : au retour du réseau, au retour dans l'app,
// et toutes les 30 s s'il reste des actions (serveur revenu sans changement de réseau).
export function startAutoSync() {
  onSyncOpportunity(syncNow)
  onConnectionLost(() => reportServer(false))
  setInterval(() => app.pending && syncNow(), 30_000)
  refreshCounts()
  syncNow()
}
