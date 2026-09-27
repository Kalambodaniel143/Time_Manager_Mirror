import { formatDateTime } from '../utils/date'

const SHIFTS = [
  { startHour: 8, startMinute: 0, hours: 8.5 },
  { startHour: 9, startMinute: 0, hours: 7.75 },
  { startHour: 8, startMinute: 30, hours: 9 },
  { startHour: 10, startMinute: 0, hours: 6.5 },
  { startHour: 9, startMinute: 30, hours: 8 },
]

function buildEntries(userId) {
  const entries = []
  const today = new Date()
  today.setHours(0, 0, 0, 0)

  let id = userId * 100

  for (let dayOffset = 20; dayOffset >= 0; dayOffset -= 1) {
    const day = new Date(today)
    day.setDate(day.getDate() - dayOffset)

    const weekday = day.getDay()
    if (weekday === 0 || weekday === 6) continue
    if ((dayOffset + userId) % 7 === 3) continue

    const shift = SHIFTS[(dayOffset + userId) % SHIFTS.length]

    const start = new Date(day)
    start.setHours(shift.startHour, shift.startMinute, 0, 0)

    const end = new Date(start.getTime() + shift.hours * 3600000)

    id += 1
    entries.push({
      id,
      start: formatDateTime(start),
      end: formatDateTime(end),
      user_id: userId,
    })
  }

  return entries
}

const store = new Map()

function entriesFor(userId) {
  if (!store.has(userId)) store.set(userId, buildEntries(userId))
  return store.get(userId)
}

export function mockListWorkingTimes(userId, filters = {}) {
  let entries = [...entriesFor(userId)]

  if (filters.start) entries = entries.filter((entry) => entry.start >= filters.start)
  if (filters.end) entries = entries.filter((entry) => entry.end <= filters.end)

  return entries.sort((a, b) => a.start.localeCompare(b.start))
}

export function mockGetWorkingTime(userId, id) {
  return entriesFor(userId).find((entry) => entry.id === Number(id)) || null
}

export function mockCreateWorkingTime(userId, attrs) {
  const entries = entriesFor(userId)
  const created = {
    id: Math.max(0, ...entries.map((entry) => entry.id)) + 1,
    start: attrs.start,
    end: attrs.end,
    user_id: userId,
  }

  entries.push(created)
  return created
}

export function mockUpdateWorkingTime(id, attrs) {
  for (const entries of store.values()) {
    const entry = entries.find((item) => item.id === Number(id))
    if (entry) {
      Object.assign(entry, attrs)
      return entry
    }
  }

  return null
}

export function mockDeleteWorkingTime(id) {
  for (const entries of store.values()) {
    const index = entries.findIndex((item) => item.id === Number(id))
    if (index !== -1) return entries.splice(index, 1)[0]
  }

  return null
}
