import { api } from './source.js'
import { app } from './appState.js'
import { setCsrfToken } from './http.js'
import { readSession, saveSession, clearSession } from '@/storage/sessionStorage.js'
import { handleError } from './network.js'

// La session enregistrée est la seule référence : relue au démarrage, à chaque
// changement de page et quand un autre onglet se connecte ou se déconnecte.
// Elle contient l'utilisateur, son organisation et le jeton CSRF — jamais le mot de passe.
export function restoreSession() {
  const session = readSession()
  const user = session?.user ?? null
  setCsrfToken(session?.csrfToken ?? null)
  if (JSON.stringify(user) !== JSON.stringify(app.user)) app.user = user
  app.organization = session?.organization ?? null
  return app.user
}

export function watchOtherTabs() {
  window.addEventListener('storage', (event) => {
    if (event.key === 'tm:session') restoreSession()
  })
}

// Réponse du serveur { csrf_token, user, organization } -> session ouverte.
function open(data) {
  saveSession({ user: data.user, organization: data.organization ?? null, csrfToken: data.csrf_token })
  app.sessionExpired = false
  return restoreSession()
}

// Le serveur dit à quelle organisation appartient le compte : on l'accepte telle quelle.
export async function login(email, password) {
  return open(await api.login(email, password))
}

// Les actions en attente restent sur le téléphone, rangées sous le compte.
export async function logout() {
  try { await api.logout() } catch { /* hors ligne : on déconnecte quand même */ }
  clearSession()
  restoreSession()
}

export function expireSession() {
  clearSession()
  restoreSession()
  app.sessionExpired = true
}

// En ligne : relire la session en base (rôle, organisation, expiration).
export async function checkSession() {
  try {
    const { user, organization } = await api.getSession()
    if (!app.user) return // déconnecté entre-temps
    saveSession({ ...readSession(), user, organization })
    restoreSession()
  } catch (error) {
    handleError(error)
  }
}
