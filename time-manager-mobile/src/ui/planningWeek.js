import { addDays, localDay, mondayOf } from './dates.js'

// Garde les jours de la semaine choisie (0 = cette semaine, 1 = la suivante).
export function daysOfWeek(planning, week) {
  const first = localDay(addDays(mondayOf(new Date()), 7 * week))
  const last = localDay(addDays(mondayOf(new Date()), 7 * week + 6))
  return (planning ?? []).filter((d) => d.date >= first && d.date <= last)
}
