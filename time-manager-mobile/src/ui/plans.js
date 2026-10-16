import { addDays, localDay, mondayOf, toUtcIso } from './dates.js'
import { hhmm } from './format.js'

// Plannings du serveur -> lignes affichables.
const TYPES = { day: 'jour', night: 'nuit', oncall: 'astreinte', leave: 'repos', rest: 'repos' }

// Deux semaines à partir du lundi courant (format des paramètres from/to).
export function planRange(weeks = 2) {
  const monday = mondayOf(new Date())
  return { from: localDay(monday), to: localDay(addDays(monday, 7 * weeks - 1)) }
}

// Toutes les gardes, avec leur planning (équipe, membres, révision), heures en ISO UTC.
export const shiftsOf = (plans) => (plans ?? []).flatMap((plan) =>
  (plan.shifts ?? []).map((s) => ({ ...s, start: toUtcIso(s.start), end: toUtcIso(s.end), plan })))

// Jours au format de PlanningList : { date, type, start, end }.
export function toDays(shifts) {
  return shifts
    .map((s) => ({ key: s.id, date: localDay(s.start), type: TYPES[s.kind] ?? 'jour', start: hhmm(s.start), end: hhmm(s.end), place: s.place }))
    .sort((a, b) => `${a.date}${a.start}`.localeCompare(`${b.date}${b.start}`))
}

export const isFuture = (shift) => new Date(shift.start) > new Date()

// Nombre de jours d'une période « du … au … » (dates AAAA-MM-JJ, bornes comprises).
export const daysBetween = (from, to) => Math.round((Date.parse(`${to}T12:00:00Z`) - Date.parse(`${from}T12:00:00Z`)) / 86_400_000) + 1
// Dernier jour d'un planning.
export const planEnd = (plan) => localDay(addDays(`${plan.start}T12:00`, plan.days - 1))

// Doublon : la même personne a déjà une garde qui chevauche ces horaires (tous plannings chargés).
// shift = { user_id, start, end } en ISO ; ignoreId = garde en cours de modification.
export function findOverlap(shift, plans, ignoreId = null) {
  const [start, end] = [Date.parse(shift.start), Date.parse(shift.end)]
  return shiftsOf(plans).find((s) => s.id !== ignoreId && s.user_id === shift.user_id
    && Date.parse(s.start) < end && start < Date.parse(s.end))
}
