import { WEEK_PATTERN } from '@/data/mock.js'
import { addDays, localDay, mondayOf, toApiTime } from '@/ui/dates.js'

// Planning fictif : semaine type, décalée d'un jour par agent.
export function planning(userId, fromWeek = 0, weeks = 2) {
  const monday = addDays(mondayOf(new Date()), 7 * fromWeek)
  return Array.from({ length: 7 * weeks }, (_, i) => ({
    date: localDay(addDays(monday, i)), ...WEEK_PATTERN[(i + userId) % 7],
  }))
}

// Pointages passés fictifs (13 semaines) : une arrivée et un départ par garde prévue.
export function pastClocks(userId) {
  const now = new Date()
  return planning(userId, -12, 13)
    .filter((p) => p.start && p.date < localDay(now))
    .flatMap((p) => {
      const start = new Date(`${p.date}T${p.start}`)
      let end = new Date(`${p.date}T${p.end}`)
      if (end <= start) end = addDays(end, 1)
      return [{ kind: 'arrival', time: start }, { kind: 'departure', time: end }]
    })
    .filter((c) => c.time < now)
    .map((c, i) => ({ id: -(i + 1), kind: c.kind, time: toApiTime(c.time), status: c.kind === 'arrival', user_id: userId }))
}

const toServer = (time) => time.slice(0, 19).replace('T', ' ')

// Comme le serveur : arrivée/reprise → pause/départ = une période travaillée.
// Identifiants uniques : agent × 100000 + rang (le propriétaire se retrouve depuis l'id).
export function workingTimes(userId, clocks) {
  const list = []
  let from = null
  for (const c of clocks) {
    if (c.kind === 'arrival' || c.kind === 'resume') from = c.time
    else if (from) { list.push({ id: userId * 100000 + list.length + 1, start: toServer(from), end: toServer(c.time), user_id: userId }); from = null }
  }
  return list
}
