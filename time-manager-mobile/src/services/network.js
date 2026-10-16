import { app } from './appState.js'
import { hasInternet } from '@/native/device.js'
import { expireSession } from './authService.js'

// Erreurs pour lesquelles on garde les données/actions et on réessaiera plus tard.
export const isUnreachable = (error) => ['network', 'timeout', 'server'].includes(error?.kind)

// Distingue « pas d'Internet » et « serveur injoignable ».
export function reportServer(reachable) {
  app.network = !hasInternet() ? 'offline' : reachable ? 'online' : 'server-down'
}

export function handleError(error) {
  if (error?.kind === 'unauthorized') expireSession()
  else if (isUnreachable(error) || !error?.kind) reportServer(false)
}
