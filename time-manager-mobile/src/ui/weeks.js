import { locale } from '@/i18n/index.js'
import { addDays, localDay, mondayOf } from './dates.js'
import { dayMonth } from './format.js'

// Semaines et mois au format attendu par le serveur.
export const weekKey = (offset = 0) => localDay(addDays(mondayOf(new Date()), 7 * offset))
export const weekLabel = (key) => `${dayMonth(`${key}T12:00`)} – ${dayMonth(addDays(`${key}T12:00`, 6))}`
export const monthKey = (offset = 0) => {
  const d = new Date()
  d.setDate(1)
  d.setMonth(d.getMonth() + offset)
  return localDay(d).slice(0, 7)
}
export const monthShort = (key) => new Date(`${key}-15T12:00`).toLocaleDateString(locale(), { month: 'short', year: '2-digit' })
export const monthLabel = (key) => new Date(`${key}-15T12:00`).toLocaleDateString(locale(), { month: 'long', year: 'numeric' })

// Saisie « datetime-local » (heure du téléphone) -> ISO UTC, et l'inverse.
export const fromInput = (value) => new Date(value).toISOString().slice(0, 19) + 'Z'
export function toInput(date) {
  const d = new Date(date)
  return `${localDay(d)}T${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}
// Format des corrections : « AAAA-MM-JJ hh:mm:ss » en UTC.
export const toUtcText = (value) => fromInput(value).replace('T', ' ').replace('Z', '')

// Semaines entières à partir du lundi courant (+ offset) : { from, to } en AAAA-MM-JJ.
export function weekRange(offset = 0, weeks = 1) {
  return { from: weekKey(offset), to: localDay(addDays(`${weekKey(offset)}T12:00`, 7 * weeks - 1)) }
}
