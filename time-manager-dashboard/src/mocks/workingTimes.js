import { formatDateTime, startOfWeek } from '../utils/date'

const WEEK_PATTERNS = {
  1: [
    [0, '05:00', 7],
    [1, '22:00', 8],
    [2, '22:00', 8],
    [5, '02:10', 2, 'oncall'],
    [6, '05:00', 7],
  ],
  4: [
    [0, '22:00', 8],
    [1, '22:00', 8],
    [2, '22:00', 8],
    [4, '08:00', 8],
  ],
  5: [0, 1, 2, 3, 4].map((day) => [day, '07:00', 7]),
  6: [
    [0, '09:00', 3],
    [1, '22:00', 5],
    [3, '23:00', 4],
  ],
  7: [0, 1, 2, 3, 4].map((day) => [day, '08:00', 8.5]),
  8: [
    ...[0, 1, 2, 3].map((day) => [day, '08:00', 7.25]),
    [5, '22:00', 8, 'oncall'],
  ],
}

const WEEKS_BACK = [1, 2]

function buildEntries(userId) {
  const pattern = WEEK_PATTERNS[userId] || []
  const thisMonday = startOfWeek(new Date())
  const entries = []
  let id = userId * 1000

  WEEKS_BACK.forEach((weeksBack) => {
    pattern.forEach(([day, time, hours, kind]) => {
      const [hh, mm] = time.split(':').map(Number)
      const start = new Date(thisMonday)
      start.setDate(start.getDate() - weeksBack * 7 + day)
      start.setHours(hh, mm, 0, 0)
      const end = new Date(start.getTime() + hours * 3600000)

      id += 1
      entries.push({
        id,
        start: formatDateTime(start),
        end: formatDateTime(end),
        user_id: userId,
        ...(kind ? { kind } : {}),
      })
    })
  })

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
    id: Math.max(userId * 1000 + 500, ...entries.map((entry) => entry.id)) + 1,
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
