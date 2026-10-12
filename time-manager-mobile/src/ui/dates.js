// Calculs de dates (heure locale du téléphone).
export const DAY_MS = 86_400_000

export function startOfDay(date) {
  const d = new Date(date)
  d.setHours(0, 0, 0, 0)
  return d
}

export function mondayOf(date) {
  const d = startOfDay(date)
  d.setDate(d.getDate() - ((d.getDay() + 6) % 7))
  return d
}

export function addDays(date, days) {
  const d = new Date(date)
  d.setDate(d.getDate() + days)
  return d
}

export function sameDay(a, b) {
  return startOfDay(a).getTime() === startOfDay(b).getTime()
}

export function weekNumber(date) {
  const d = mondayOf(date)
  const thursday = addDays(d, 3)
  const firstThursday = addDays(mondayOf(new Date(thursday.getFullYear(), 0, 4)), 3)
  return 1 + Math.round((thursday - firstThursday) / (7 * DAY_MS))
}

// Heure exacte au format attendu par l'API : ISO UTC à la seconde.
export function toApiTime(date = new Date()) {
  return new Date(date).toISOString().slice(0, 19) + 'Z'
}

// Heure envoyée par le serveur -> ISO UTC avec Z.
// Le serveur compte en UTC mais n'écrit pas toujours le fuseau :
// « 2026-10-09 12:00:00 » et « 2026-10-09T12:00:00 » sont de l'UTC,
// pas l'heure locale du téléphone (sinon +2 h à Paris en été).
export function toUtcIso(value) {
  const text = String(value).trim().replace(' ', 'T')
  const hasZone = /(Z|[+-]\d{2}:?\d{2})$/i.test(text)
  return hasZone ? new Date(text).toISOString().slice(0, 19) + 'Z' : `${text.slice(0, 19)}Z`
}

export const parseApiDate = (value) => new Date(toUtcIso(value))

// « AAAA-MM-JJ » dans le fuseau du téléphone.
export function localDay(date) {
  const d = new Date(date)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}
