import { addDays, mondayOf, parseApiDate } from './dates.js'
import { maxConsecutiveNights, shiftType } from './shifts.js'

// Résumé de la semaine en cours d'un agent à partir de ses heures travaillées.
export function weekSummary(workingTimes) {
  const monday = mondayOf(new Date())
  const periods = (workingTimes ?? [])
    .map((p) => ({ start: parseApiDate(p.start), end: parseApiDate(p.end) }))
    .filter((p) => p.start >= monday && p.start < addDays(monday, 7))
  const sum = (list) => list.reduce((total, p) => total + (p.end - p.start), 0)
  return {
    total: sum(periods),
    night: sum(periods.filter((p) => shiftType(p.start) === 'nuit')),
    nightsInARow: maxConsecutiveNights(periods),
  }
}
