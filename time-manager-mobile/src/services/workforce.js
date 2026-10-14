import { t } from '@/i18n/index.js'
import { api } from './source.js'
import { load } from './dataService.js'
import { handleError, isUnreachable, reportServer } from './network.js'

// Lectures et actions des nouvelles fonctions (planning, demandes, semaines, paie…).
// Si le serveur n'a pas encore la route (404), on le dit clairement au lieu d'une erreur obscure.
export const NOT_INSTALLED = t('Cette fonction n’est pas encore installée sur le serveur.')
// Route absente : 404 sans message précis (Phoenix répond « Not Found » ou un corps vide).
export const isNotInstalled = (error) => error?.status === 404 && (!error.payload?.errors?.detail || /not found/i.test(error.payload.errors.detail))

function explain(error) {
  if (isNotInstalled(error)) return new Error(NOT_INSTALLED)
  if (isUnreachable(error) || !error?.kind) return new Error(t('Connexion au serveur nécessaire pour cette action.'))
  if (error.kind === 'forbidden') return new Error(t('Le serveur n’autorise pas cette action pour votre rôle.'))
  return error
}

// Lecture gardée sur le téléphone : consultable hors ligne (données marquées anciennes).
export async function read(name, fetcher) {
  try { return await load(name, fetcher) } catch (error) { throw explain(error) }
}

// Action : demande le serveur, pas de file d'attente (une décision doit être vue tout de suite).
export async function act(call) {
  try {
    const result = await call()
    reportServer(true)
    return result
  } catch (error) {
    handleError(error)
    throw explain(error)
  }
}

export { api }
