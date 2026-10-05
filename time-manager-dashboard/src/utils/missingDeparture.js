import { formatClockDate } from './clockDate'

// Une alerte de vérification après 24 h, pas simplement au passage de minuit.
export const MISSING_DEPARTURE_DELAY = 24 * 60 * 60 * 1000
export const CORRECTION_WINDOW = 7 * 24 * 60 * 60 * 1000

export function clockDate(value) {
  return new Date(`${formatClockDate(value).replace(' ', 'T')}Z`)
}

export function findMissingDeparture(clocks, now) {
  let service = null
  for (const clock of clocks) {
    if (!clock || !Number.isInteger(clock.id) || typeof clock.status !== 'boolean') throw new Error('Pointage invalide')
    clockDate(clock.time)
    const kind = clock.kind || (clock.status ? 'arrival' : 'departure')
    if (!['arrival', 'departure', 'pause', 'resume'].includes(kind)) throw new Error('Type de pointage invalide')
    if (kind === 'arrival') service = { arrival: clock, last: clock }
    else if (kind === 'departure') service = null
    else if (service) service.last = clock
  }

  if (!service || now.getTime() - clockDate(service.arrival.time).getTime() < MISSING_DEPARTURE_DELAY) return null
  return service
}

// datetime-local attend l'heure locale. L'envoi à Phoenix sera reconverti en UTC.
export function localDateInput(date) {
  const pad = (value) => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

export function departureError(value, lastClock, now) {
  if (!value) return 'Indiquez la date et l’heure réelles de votre départ.'
  const date = new Date(value)
  // Refuser aussi une heure locale inexistante lors d'un changement d'heure.
  if (Number.isNaN(date.getTime()) || localDateInput(date) !== (value.length === 16 ? `${value}:00` : value)) {
    return 'Cette date ou cette heure est invalide.'
  }
  if (date > now) return 'Le départ ne peut pas être dans le futur.'
  if (date.getTime() < now.getTime() - CORRECTION_WINDOW) return 'Seuls les départs des 7 derniers jours peuvent être complétés.'
  const last = clockDate(lastClock.time)
  if (date < last || (lastClock.status && date.getTime() === last.getTime())) return 'Le départ doit suivre le dernier pointage enregistré.'
  return ''
}
