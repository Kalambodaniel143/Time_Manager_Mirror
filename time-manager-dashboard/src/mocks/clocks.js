import { formatClockDate } from '../utils/clockDate'

const store = new Map()

function clocksFor(userId) {
  if (!store.has(userId)) {
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const entries = []
    let id = userId * 1000

    for (let dayOffset = 4; dayOffset >= 1; dayOffset -= 1) {
      const day = new Date(today)
      day.setDate(day.getDate() - dayOffset)

      const clockIn = new Date(day)
      clockIn.setHours(9, 0, 0, 0)

      const clockOut = new Date(day)
      clockOut.setHours(17, 30, 0, 0)

      id += 1
      entries.push({ id, time: formatClockDate(clockIn), status: true, user_id: userId })
      id += 1
      entries.push({ id, time: formatClockDate(clockOut), status: false, user_id: userId })
    }

    store.set(userId, entries)
  }

  return store.get(userId)
}

export function mockListClocks(userId) {
  return [...clocksFor(userId)].sort((a, b) => a.time.localeCompare(b.time) || a.id - b.id)
}

export function mockCreateClock(userId, attrs) {
  const entries = clocksFor(userId)

  const created = {
    id: Math.max(0, ...entries.map((entry) => entry.id)) + 1,
    time: formatClockDate(attrs.time),
    status: attrs.status,
    kind: attrs.kind || (attrs.status ? 'arrival' : 'departure'),
    user_id: userId,
  }

  entries.push(created)
  return created
}
