import { durationInHours, parseDateTime, startOfWeek, toDateInput } from './date'

export const KIND_LABELS = {
  day: 'Jour',
  night: 'Nuit ×1,5',
  oncall: 'Astreinte',
  sup: 'Heures sup. ×2',
  recup: 'Récup · non payée',
  leave: 'Congé',
  rest: 'Repos',
}

export const KIND_SHORT = {
  day: 'Jour',
  night: 'Nuit',
  oncall: 'Astr.',
  leave: 'Congé',
  rest: 'Repos',
}

export const KIND_ICONS = {
  day: 'sun',
  night: 'moon',
  oncall: 'siren',
  sup: 'alarm',
  recup: 'rotate',
  leave: 'palm',
}

const FIXED_KINDS = ['oncall', 'leave', 'recup']
const STEP_MINUTES = 5

function pad(value) {
  return String(value).padStart(2, '0')
}

export function addDays(date, days) {
  const copy = new Date(date)
  copy.setDate(copy.getDate() + days)
  return copy
}

export function isNightHour(hour) {
  return hour >= 22 || hour < 6
}

function nightShare(entry) {
  const from = parseDateTime(entry.start)
  const to = parseDateTime(entry.end)
  if (!from || !to || to <= from) return 0

  let night = 0
  let total = 0
  for (let time = from.getTime(); time < to.getTime(); time += STEP_MINUTES * 60000) {
    total += 1
    if (isNightHour(new Date(time).getHours())) night += 1
  }

  return total ? night / total : 0
}

export function classifyEntry(entry) {
  if (FIXED_KINDS.includes(entry.kind)) return entry.kind
  return nightShare(entry) >= 0.5 ? 'night' : 'day'
}

export function entryHours(entry) {
  return Math.max(durationInHours(entry.start, entry.end), 0)
}

export function weekBuckets(entries, overtimeThreshold = 40) {
  const buckets = { day: 0, night: 0, oncall: 0, sup: 0, recup: 0, leave: 0 }

  entries.forEach((entry) => {
    buckets[classifyEntry(entry)] += entryHours(entry)
  })

  const base = buckets.day + buckets.night
  if (base > overtimeThreshold) {
    let excess = base - overtimeThreshold
    buckets.sup = excess
    const fromDay = Math.min(excess, buckets.day)
    buckets.day -= fromDay
    excess -= fromDay
    buckets.night -= Math.min(excess, buckets.night)
  }

  buckets.total = buckets.day + buckets.night + buckets.oncall + buckets.sup + buckets.recup + buckets.leave
  return buckets
}

export function formatHours(hours) {
  const minutes = Math.round((Number(hours) || 0) * 60)
  const whole = Math.floor(minutes / 60)
  const rest = minutes % 60
  const head = `${whole.toLocaleString('fr-FR')} h`
  return rest ? `${head} ${pad(rest)}` : head
}

export function formatClock(value) {
  const date = parseDateTime(value)
  return date ? `${pad(date.getHours())}:${pad(date.getMinutes())}` : ''
}

export function mondayOf(value = new Date()) {
  return startOfWeek(value)
}

export function isoWeek(value) {
  const date = new Date(value)
  date.setHours(0, 0, 0, 0)
  date.setDate(date.getDate() + 3 - ((date.getDay() + 6) % 7))
  const firstThursday = new Date(date.getFullYear(), 0, 4)
  return 1 + Math.round(((date - firstThursday) / 86400000 - 3 + ((firstThursday.getDay() + 6) % 7)) / 7)
}

function monthShort(date) {
  return date.toLocaleDateString('fr-FR', { month: 'short' })
}

export function formatRange(from, to) {
  if (from.getMonth() === to.getMonth()) return `${from.getDate()} – ${to.getDate()} ${monthShort(to)}`
  return `${from.getDate()} ${monthShort(from)} – ${to.getDate()} ${monthShort(to)}`
}

export function formatDayMonthLong(date) {
  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long' })
}

export function weekdayShort(date) {
  const label = date.toLocaleDateString('fr-FR', { weekday: 'short' })
  return label.charAt(0).toUpperCase() + label.slice(1)
}

export function weekdayUpper(date) {
  return date.toLocaleDateString('fr-FR', { weekday: 'short' }).toUpperCase()
}

export function weekFilters(monday) {
  return {
    start: `${toDateInput(monday)} 00:00:00`,
    end: `${toDateInput(addDays(monday, 6))} 23:59:59`,
  }
}

export function entriesByDay(entries, monday) {
  return Array.from({ length: 7 }, (_, index) => {
    const key = toDateInput(addDays(monday, index))
    return entries.filter((entry) => entry.start.slice(0, 10) === key)
  })
}

export function longestRun(kinds, target = 'night') {
  let best = { length: 0, start: -1 }
  let current = { length: 0, start: -1 }

  kinds.forEach((kind, index) => {
    if (kind === target) {
      current = current.length ? { length: current.length + 1, start: current.start } : { length: 1, start: index }
      if (current.length > best.length) best = { ...current }
    } else {
      current = { length: 0, start: -1 }
    }
  })

  return best
}

export function weekNightRun(entries, monday) {
  const kinds = entriesByDay(entries, monday).map((day) =>
    day.some((entry) => classifyEntry(entry) === 'night') ? 'night' : 'other',
  )
  return longestRun(kinds).length
}

// Count nights by service day; several work segments from one night count once.
export function nightFrequency(entries) {
  const days = new Set(entries.filter(entry => classifyEntry(entry) === 'night').map(entry => entry.start.slice(0, 10)))
  const months = {}
  days.forEach(day => { const month = day.slice(0, 7); months[month] = (months[month] || 0) + 1 })
  return { total: days.size, months }
}
