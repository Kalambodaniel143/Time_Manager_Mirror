// Horloge du serveur, estimée avec l'en-tête HTTP « Date » de ses réponses.
// Le serveur refuse un pointage daté après sa propre heure : si le téléphone
// avance de quelques secondes, l'heure envoyée est ramenée à celle du serveur.
let offsetMs = 0

export function noteServerDate(dateHeader) {
  const server = Date.parse(dateHeader ?? '')
  if (!Number.isNaN(server)) offsetMs = server - Date.now()
}

export const serverNow = () => new Date(Date.now() + offsetMs)

// Heure ISO jamais postérieure à « maintenant » côté serveur (marge d'1 s, l'en-tête est à la seconde).
export function notAfterServerNow(isoTime) {
  const limit = serverNow().getTime() - 1000
  return Date.parse(isoTime) > limit ? new Date(limit).toISOString().slice(0, 19) + 'Z' : isoTime
}
