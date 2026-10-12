// Stockage persistant de la WebView : il survit à la fermeture de l'application.
// Les écritures ne sont pas protégées par try/catch : si elles échouent,
// l'appelant le sait et n'annonce pas un pointage comme enregistré.
const PREFIX = 'tm:'

export function read(key, fallback = null) {
  try {
    const raw = localStorage.getItem(PREFIX + key)
    return raw ? JSON.parse(raw) : fallback
  } catch {
    return fallback
  }
}

export function write(key, value) {
  localStorage.setItem(PREFIX + key, JSON.stringify(value))
}

export function remove(key) {
  localStorage.removeItem(PREFIX + key)
}
