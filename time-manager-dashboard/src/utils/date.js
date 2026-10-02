import { formatClockDate } from './clockDate'

const API_PATTERN = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?/

function pad(value) {
  return String(value).padStart(2, '0')
}

export function parseDateTime(value) {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value
  if (typeof value !== 'string') return null

  const match = value.match(API_PATTERN)
  if (!match) return null

  const [, year, month, day, hours, minutes, seconds] = match
  const date = new Date(
    Number(year),
    Number(month) - 1,
    Number(day),
    Number(hours),
    Number(minutes),
    Number(seconds || 0),
  )

  return Number.isNaN(date.getTime()) ? null : date
}

export function formatDateTime(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    ` ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  )
}

export function toInputValue(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  )
}

export function fromInputValue(value) {
  return formatDateTime(value)
}

export function isValidDateTime(value) {
  return parseDateTime(value) !== null
}

export function nowFormatted() {
  return formatDateTime(new Date())
}

export function durationInHours(start, end) {
  // Les dates de l'API sont en UTC : un changement d'heure local ne doit
  // pas ajouter ou enlever une heure au total travaillé.
  try {
    const from = Date.parse(`${formatClockDate(start).replace(' ', 'T')}Z`)
    const to = Date.parse(`${formatClockDate(end).replace(' ', 'T')}Z`)
    return (to - from) / 3600000
  } catch {
    return 0
  }
}

export function formatDuration(hours) {
  // Arrondir à la seconde pour garder les pointages courts visibles.
  const totalSeconds = Number.isFinite(hours) && hours > 0 ? Math.round(hours * 3600) : 0
  const wholeHours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  return `${wholeHours}h ${pad(minutes)}m ${pad(seconds)}s`
}

export function formatDayLabel(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  return date.toLocaleDateString('fr-FR', { weekday: 'short', day: '2-digit', month: 'short' })
}

export function formatTimeLabel(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

export function formatHumanTime(value) {
  return formatTimeLabel(value)
}

export function formatLongDate(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  return date.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })
}

export function formatWeekday(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  const label = date.toLocaleDateString('fr-FR', { weekday: 'short' })
  return label.charAt(0).toUpperCase() + label.slice(1)
}

export function formatDayMonth(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })
}

export function toDateInput(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
}

export function toTimeInput(value) {
  const date = parseDateTime(value)
  if (!date) return ''

  return `${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
}

export function combineDateTime(day, time, dayOffset = 0) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day || '') || !/^\d{2}:\d{2}(?::\d{2})?$/.test(time || '')) return ''

  const [year, month, date] = day.split('-').map(Number)
  const [hours, minutes, seconds = 0] = time.split(':').map(Number)

  return formatDateTime(new Date(year, month - 1, date + dayOffset, hours, minutes, seconds))
}

export function todayInput() {
  return toDateInput(new Date())
}

export function startOfWeek(value) {
  const date = new Date(parseDateTime(value) || value)
  date.setHours(0, 0, 0, 0)

  const offset = (date.getDay() + 6) % 7
  date.setDate(date.getDate() - offset)

  return date
}

export function hourOfDay(value) {
  const date = parseDateTime(value)
  if (!date) return 0

  return date.getHours() + date.getMinutes() / 60 + date.getSeconds() / 3600
}

export function isSameDay(a, b) {
  return toDateInput(a) === toDateInput(b)
}
