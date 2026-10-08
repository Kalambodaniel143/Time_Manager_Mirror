import assert from 'node:assert/strict'
import process from 'node:process'
import { after, afterEach, before, beforeEach, test } from 'node:test'
import { createServer } from 'vite'

let server
let ClockManager
let App
let WorkingTimes
let MissingDeparture
let EmployeeToday
let TeamOverview
let team
let org
let isValidated
let findMissingDeparture
let departureError
let localDateInput
let durationInHours
let formatClockDate
const originalFetch = globalThis.fetch
const instances = []

function response(data, status = 200) {
  return { ok: status < 400, status, json: async () => ({ data }) }
}

function deferred() {
  let resolve
  const promise = new Promise((done) => { resolve = done })
  return { promise, resolve }
}

function component(userId = '1') {
  const vm = { ...ClockManager.data(), userId, events: [] }
  vm.$emit = (event) => vm.events.push(event)
  for (const [name, getter] of Object.entries(ClockManager.computed)) {
    Object.defineProperty(vm, name, { get: () => getter.call(vm) })
  }
  instances.push(vm)
  for (const [name, method] of Object.entries(ClockManager.methods)) vm[name] = method.bind(vm)
  return vm
}

before(async () => {
  server = await createServer({ server: { middlewareMode: true, hmr: false }, appType: 'custom' })
  ClockManager = (await server.ssrLoadModule('/src/components/ClockManager.vue')).default
  App = (await server.ssrLoadModule('/src/App.vue')).default
  WorkingTimes = (await server.ssrLoadModule('/src/components/WorkingTimes.vue')).default
  MissingDeparture = (await server.ssrLoadModule('/src/components/MissingDeparture.vue')).default
  EmployeeToday = (await server.ssrLoadModule('/src/views/EmployeeToday.vue')).default
  TeamOverview = (await server.ssrLoadModule('/src/views/TeamOverview.vue')).default
  ;({ team, org, isValidated } = await server.ssrLoadModule('/src/services/orgService.js'))
  ;({ findMissingDeparture, departureError, localDateInput } = await server.ssrLoadModule('/src/utils/missingDeparture.js'))
  ;({ durationInHours } = await server.ssrLoadModule('/src/utils/date.js'))
  ;({ formatClockDate } = await server.ssrLoadModule('/src/utils/clockDate.js'))
})

beforeEach(() => {
  globalThis.fetch = async () => { throw new Error('Unexpected HTTP request') }
})

afterEach(() => {
  for (const vm of instances.splice(0)) ClockManager.beforeUnmount.call(vm)
})

after(async () => {
  globalThis.fetch = originalFetch
  await server?.close()
})

test('empty history is idle; refresh uses the user API route', async () => {
  globalThis.fetch = async (url) => {
    assert.equal(url, '/api/clocks/12')
    return response([])
  }
  const vm = component('12')
  await vm.refresh()
  assert.equal(vm.clockIn, false)
  assert.equal(vm.startDateTime, null)
  assert.equal(vm.ready, true)
  assert.equal(vm.loading, false)
})

test('arrival then departure POST correct JSON, preserve false, and reload the saved state', async () => {
  const entries = []
  const statuses = []
  globalThis.fetch = async (url, options) => {
    assert.equal(url, '/api/clocks/1')
    if (options.method === 'POST') {
      const body = JSON.parse(options.body)
      assert.deepEqual(Object.keys(body), ['clock'])
      assert.match(body.clock.time, /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/)
      statuses.push(body.clock.status)
      const entry = { ...body.clock, id: entries.length + 1, user_id: 1 }
      entries.push(entry)
      return response(entry, 201)
    }
    return response(entries)
  }
  const vm = component()
  await vm.refresh()
  await vm.clock()
  assert.equal(vm.clockIn, true)
  assert.ok(vm.startDateTime)
  await vm.clock()
  assert.equal(vm.clockIn, false)
  assert.equal(vm.startDateTime, null)
  assert.deepEqual(statuses, [true, false])
  assert.deepEqual(vm.events, ['changed', 'changed'])
})

test('new component restores an active clock, with ISO converted to subject format', async () => {
  globalThis.fetch = async () => response([{ status: true, time: '2026-09-24T09:00:00Z' }])
  const vm = component()
  await vm.refresh()
  assert.equal(vm.clockIn, true)
  assert.equal(vm.startDateTime, '2026-09-24 09:00:00')
})

test('404 leaves state unknown and prevents a POST', async () => {
  let requests = 0
  globalThis.fetch = async () => { requests += 1; return response(null, 404) }
  const vm = component()
  await vm.refresh()
  await vm.clock()
  assert.equal(requests, 1)
  assert.equal(vm.ready, false)
  assert.match(vm.error, /introuvable/)
  assert.equal(vm.loading, false)
})

test('failed POST requires refresh before retrying; does not report success', async () => {
  let posts = 0
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') { posts += 1; throw new Error('Network down') }
    return response([])
  }
  const vm = component()
  await vm.refresh()
  await vm.clock()
  await vm.clock()
  assert.equal(posts, 1)
  assert.equal(vm.ready, false)
  assert.equal(vm.loading, false)
  assert.deepEqual(vm.events, [])
  assert.match(vm.error, /non confirmé/)
})

test('double click creates one POST only', async () => {
  const pending = deferred()
  let posts = 0
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') { posts += 1; return pending.promise }
    return response([])
  }
  const vm = component()
  await vm.refresh()
  const first = vm.clock()
  await vm.clock()
  assert.equal(posts, 1)
  pending.resolve(response({ status: true }, 201))
  await first
  assert.equal(vm.loading, false)
})

test('old response cannot overwrite a newer refresh, including A → B → A navigation', async () => {
  const pending = deferred()
  let calls = 0
  globalThis.fetch = async () => {
    calls += 1
    return calls === 1 ? pending.promise : response([])
  }
  const vm = component('1')
  const old = vm.refresh()
  vm.userId = '2'
  await vm.refresh()
  vm.userId = '1'
  await vm.refresh()
  pending.resolve(response([{ status: true, time: '2026-09-24T09:00:00Z' }]))
  await old
  assert.equal(vm.clockIn, false)
  assert.equal(vm.startDateTime, null)
})

test('leaving the component invalidates its pending response', async () => {
  const pending = deferred()
  globalThis.fetch = () => pending.promise
  const vm = component()
  const load = vm.refresh()
  ClockManager.beforeUnmount.call(vm)
  pending.resolve(response([{ status: true, time: '2026-09-24T09:00:00Z' }]))
  await load
  assert.equal(vm.ready, false)
})

test('malformed server response is not mistaken for an empty history', async () => {
  globalThis.fetch = async () => response(null)
  const vm = component()
  await vm.refresh()
  assert.equal(vm.ready, false)
  assert.ok(vm.error)
})

test('invalid event kinds or dates leave the clock unknown and prevent writes', async () => {
  const vm = component()
  for (const entry of [
    { kind: 'unknown', status: true, time: '2026-09-24T09:00:00Z' },
    { kind: 'arrival', status: true, time: 'invalid' },
  ]) {
    let requests = 0
    globalThis.fetch = async () => { requests += 1; return response([entry]) }
    await vm.refresh()
    await vm.clock()
    assert.equal(vm.ready, false)
    assert.equal(vm.timerId, null)
    assert.ok(vm.error)
    assert.equal(requests, 1)
  }
})

test('a pending write cannot change the newly selected user or emit success there', async () => {
  const pending = deferred()
  globalThis.fetch = async (_url, options) => options.method === 'POST' ? pending.promise : response([])
  const vm = component('1')
  await vm.refresh()
  const save = vm.clock()
  vm.userId = '2'
  await vm.refresh()
  pending.resolve(response({ status: true, time: '2026-09-24T09:00:00Z' }, 201))
  await save
  assert.equal(vm.clockIn, false)
  assert.equal(vm.ready, true)
  assert.equal(vm.loading, false)
  assert.deepEqual(vm.events, [])
})

test('UTC date convention handles offsets, space format and invalid dates', () => {
  assert.equal(formatClockDate('2026-09-24T11:00:00+02:00'), '2026-09-24 09:00:00')
  assert.equal(formatClockDate('2026-09-24 09:00:00'), '2026-09-24 09:00:00')
  assert.throws(() => formatClockDate('not-a-date'))
  assert.throws(() => formatClockDate(null))
})

test('clock change reloads dashboard totals and the period list without losing filters', async () => {
  const period = { start: '2026-09-28 09:00:00', end: '2026-09-28 17:00:00' }
  const requests = []
  globalThis.fetch = async (url) => {
    requests.push(url)
    return response([period])
  }
  const list = { userId: 1, filters: { start: '2026-09-28 00:00:00' } }
  list.getWorkingTimes = WorkingTimes.methods.getWorkingTimes.bind(list)
  const vm = { ...App.data(), userId: 1, $refs: { list } }
  for (const [name, method] of Object.entries(App.methods)) vm[name] = method.bind(vm)
  await vm.onPeriodsChanged()
  assert.equal(App.computed.totalHours.call(vm), 8)
  assert.deepEqual(list.workingTimes, [period])
  assert.equal(list.filters.start, '2026-09-28 00:00:00')
  assert.equal(requests.length, 2)
  assert.equal(requests[0], '/api/workingtime/1')
  const filtered = new URL(requests[1], 'http://localhost')
  assert.equal(filtered.pathname, '/api/workingtime/1')
  assert.equal(filtered.searchParams.get('start'), list.filters.start)
  assert.equal(vm.loadingStats, false)
  assert.equal(list.loading, false)
})

for (const routeName of ['clock', 'overview']) {
  test(`${routeName} clock events reload totals when the period list is not mounted`, async () => {
    globalThis.fetch = async (url) => {
      assert.equal(url, '/api/workingtime/12')
      return response([{ start: '2026-09-28 09:00:00', end: '2026-09-28 17:00:00' }])
    }
    const vm = { ...App.data(), userId: 12, $route: { name: routeName }, $refs: {} }
    for (const [name, method] of Object.entries(App.methods)) vm[name] = method.bind(vm)
    const listeners = App.computed.routeListeners.call(vm)
    await listeners.onChanged()
    assert.equal(App.computed.totalHours.call(vm), 8)
    assert.equal(vm.workingTimes.length, 1)
  })
}

test('UTC working durations remain correct across daylight saving changes', () => {
  assert.equal(durationInHours('2026-03-29 00:00:00', '2026-03-29 08:00:00'), 8)
  assert.equal(durationInHours('2026-10-25 00:00:00', '2026-10-25 08:00:00'), 8)
  assert.equal(durationInHours('2026-09-28T11:00:00+02:00', '2026-09-28T17:00:00Z'), 8)
})

test('server validation errors are displayed and block another clock until refreshed', async () => {
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') {
      return { ok: false, status: 422, json: async () => ({ errors: { status: ['must alternate arrivals and departures'] } }) }
    }
    return response([])
  }
  const vm = component()
  await vm.refresh()
  await vm.clock()
  assert.match(vm.error, /must alternate/)
  assert.equal(vm.ready, false)
  assert.deepEqual(vm.events, [])
})


test('active timer restores the arrival, ticks locally, and catches up after a delayed tick', async (t) => {
  const start = Date.parse('2026-09-29T09:00:00Z')
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: start + 310000 })
  let reads = 0
  globalThis.fetch = async () => {
    reads += 1
    return response([{ status: true, time: '2026-09-29T09:00:00Z' }])
  }
  const vm = component()
  await vm.refresh()
  assert.equal(vm.elapsedTime, '00:05:10')
  t.mock.timers.tick(1000)
  assert.equal(vm.elapsedTime, '00:05:11')
  t.mock.timers.setTime(start + 3600000)
  t.mock.timers.tick(1000)
  assert.equal(vm.elapsedTime, '01:00:01')
  assert.equal(reads, 1)
})

test('arrival starts the timer and successful departure stops and resets it', async (t) => {
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: Date.parse('2026-09-29T09:00:00Z') })
  const entries = []
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') {
      const { clock } = JSON.parse(options.body)
      entries.push(clock)
      return response(clock, 201)
    }
    return response(entries)
  }
  const vm = component()
  await vm.refresh()
  assert.equal(vm.timerId, null)
  await vm.clock()
  t.mock.timers.tick(2100)
  assert.equal(vm.elapsedTime, '00:00:02')
  await vm.clock()
  assert.equal(vm.clockIn, false)
  assert.equal(vm.startDateTime, null)
  assert.equal(vm.elapsedTime, '00:00:00')
  assert.equal(vm.timerId, null)
  const stoppedAt = vm.currentTime
  t.mock.timers.tick(5000)
  assert.equal(vm.currentTime, stoppedAt)
})

test('refresh replaces the timer and switching user ignores a late active response', async (t) => {
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: Date.parse('2026-09-29T09:05:10Z') })
  const arrival = [{ status: true, time: '2026-09-29T09:00:00Z' }]
  globalThis.fetch = async () => response(arrival)
  const vm = component()
  await vm.refresh()
  const oldId = vm.timerId
  await vm.refresh()
  assert.notEqual(vm.timerId, oldId)
  assert.equal(vm.elapsedTime, '00:05:10')
  const pending = deferred()
  globalThis.fetch = () => pending.promise
  const oldRefresh = vm.refresh()
  assert.equal(vm.timerId, null)
  assert.equal(vm.ready, false)
  vm.userId = '2'
  globalThis.fetch = async () => response([])
  await vm.refresh()
  pending.resolve(response(arrival))
  await oldRefresh
  assert.equal(vm.clockIn, false)
  assert.equal(vm.elapsedTime, '00:00:00')
  assert.equal(vm.timerId, null)
  const stoppedAt = vm.currentTime
  t.mock.timers.tick(5000)
  assert.equal(vm.currentTime, stoppedAt)
})

test('a failed refresh stops the timer while the clock state is unknown', async (t) => {
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: Date.parse('2026-09-29T09:05:10Z') })
  globalThis.fetch = async () => response([{ status: true, time: '2026-09-29T09:00:00Z' }])
  const vm = component()
  await vm.refresh()
  globalThis.fetch = async () => { throw new Error('Network down') }
  await vm.refresh()
  assert.equal(vm.ready, false)
  assert.equal(vm.elapsedTime, '00:00:00')
  assert.equal(vm.timerId, null)
  const stoppedAt = vm.currentTime
  t.mock.timers.tick(5000)
  assert.equal(vm.currentTime, stoppedAt)
})

test('a failed departure stops the timer until the state is confirmed again', async (t) => {
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: Date.parse('2026-09-29T09:05:10Z') })
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') throw new Error('Network down')
    return response([{ status: true, time: '2026-09-29T09:00:00Z' }])
  }
  const vm = component()
  await vm.refresh()
  await vm.clock()
  assert.equal(vm.ready, false)
  assert.equal(vm.elapsedTime, '00:00:00')
  assert.equal(vm.timerId, null)
  await vm.refresh()
  t.mock.timers.tick(1000)
  assert.equal(vm.elapsedTime, '00:05:11')
})

test('unmount stops the interval so the abandoned component no longer updates', async (t) => {
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: Date.parse('2026-09-29T09:05:10Z') })
  globalThis.fetch = async () => response([{ status: true, time: '2026-09-29T09:00:00Z' }])
  const vm = component()
  await vm.refresh()
  ClockManager.beforeUnmount.call(vm)
  assert.equal(vm.timerId, null)
  const stoppedAt = vm.currentTime
  t.mock.timers.tick(5000)
  assert.equal(vm.currentTime, stoppedAt)
})

test('elapsed time pads each part, handles rollovers and keeps hours beyond one day', () => {
  const vm = component()
  vm.ready = true
  vm.clockIn = true
  vm.startDateTime = '2026-09-29 09:00:00'
  const start = Date.parse('2026-09-29T09:00:00Z')
  for (const [seconds, label] of [
    [-1, '00:00:00'], [59, '00:00:59'], [60, '00:01:00'],
    [3599, '00:59:59'], [3600, '01:00:00'], [90061, '25:01:01'],
  ]) {
    vm.currentTime = start + seconds * 1000
    assert.equal(vm.elapsedTime, label)
  }
  vm.startDateTime = 'invalid'
  assert.equal(vm.elapsedTime, '00:00:00')
})

test('pause freezes the total, survives reload, and resume excludes the break', async (t) => {
  const nine = Date.parse('2026-10-05T09:00:00Z')
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: nine })
  const entries = []
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') {
      const { clock } = JSON.parse(options.body)
      assert.equal(clock.status, ['arrival', 'resume'].includes(clock.kind))
      entries.push(clock)
      return response(clock, 201)
    }
    return response(entries)
  }

  const vm = component()
  await vm.refresh()
  await vm.clock()
  t.mock.timers.setTime(nine + 3600000)
  t.mock.timers.tick(1000)
  await vm.clock('pause')
  assert.equal(vm.onBreak, true)
  assert.equal(vm.clockIn, false)
  assert.equal(vm.startDateTime, null)
  assert.equal(vm.elapsedTime, '01:00:01')
  assert.equal(vm.timerId, null)
  assert.equal(vm.clockButtonLabel, 'Reprendre')
  t.mock.timers.tick(1800000)
  assert.equal(vm.elapsedTime, '01:00:01')

  const reloaded = component()
  await reloaded.refresh()
  assert.equal(reloaded.stateLabel, 'En pause')
  assert.equal(reloaded.elapsedTime, '01:00:01')
  assert.equal(reloaded.timerId, null)
  await reloaded.clock()
  assert.equal(reloaded.clockIn, true)
  assert.equal(reloaded.onBreak, false)
  t.mock.timers.setTime(nine + 3 * 3600000)
  t.mock.timers.tick(1000)
  assert.equal(reloaded.elapsedTime, '02:30:01')
  await reloaded.refresh()
  assert.equal(reloaded.elapsedTime, '02:30:01')
  await reloaded.clock()
  assert.equal(reloaded.stateLabel, 'Hors service')
  assert.equal(reloaded.elapsedTime, '00:00:00')
  assert.deepEqual(entries.map((entry) => entry.kind), ['arrival', 'pause', 'resume', 'departure'])
})

test('several pauses accumulate only work from the current service', async (t) => {
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: Date.parse('2026-10-05T12:00:00Z') })
  const events = [
    ['08:00:00', true, 'arrival'], ['08:30:00', false, 'departure'],
    ['09:00:00', true, 'arrival'], ['10:00:00', false, 'pause'],
    ['10:30:00', true, 'resume'], ['11:00:00', false, 'pause'],
    ['11:15:00', true, 'resume'],
  ].map(([time, status, kind]) => ({ time: `2026-10-05 ${time}`, status, kind }))
  globalThis.fetch = async () => response(events)
  const vm = component()
  await vm.refresh()
  assert.equal(vm.elapsedTime, '02:15:00')
  vm.userId = '2'
  globalThis.fetch = async () => response([])
  await vm.refresh()
  assert.equal(vm.elapsedTime, '00:00:00')
  assert.equal(vm.onBreak, false)
  assert.equal(vm.workedSeconds, 0)
})

test('departure during a pause closes the service without requesting a resume', async () => {
  const events = [
    { time: '2026-10-05 09:00:00', status: true, kind: 'arrival' },
    { time: '2026-10-05 10:00:00', status: false, kind: 'pause' },
  ]
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') {
      const { clock } = JSON.parse(options.body)
      assert.equal(clock.kind, 'departure')
      assert.equal(clock.status, false)
      events.push(clock)
      return response(clock, 201)
    }
    return response(events)
  }
  const vm = component()
  await vm.refresh()
  await vm.clock('departure')
  assert.equal(vm.onBreak, false)
  assert.equal(vm.clockIn, false)
  assert.equal(vm.workedSeconds, 0)
  assert.equal(vm.elapsedTime, '00:00:00')
  assert.equal(vm.timerId, null)
})

test('failed pause stays unknown until the saved state is read again', async (t) => {
  t.mock.timers.enable({ apis: ['Date', 'setInterval'], now: Date.parse('2026-10-05T10:00:00Z') })
  const events = [{ time: '2026-10-05 09:00:00', status: true, kind: 'arrival' }]
  let posts = 0
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') {
      posts += 1
      events.push(JSON.parse(options.body).clock)
      throw new Error('Response lost after saving')
    }
    return response(events)
  }
  const vm = component()
  await vm.refresh()
  await vm.clock('pause')
  assert.equal(vm.ready, false)
  assert.equal(vm.timerId, null)
  await vm.clock('pause')
  assert.equal(posts, 1)
  await vm.refresh()
  assert.equal(vm.onBreak, true)
  assert.equal(vm.elapsedTime, '01:00:00')
  t.mock.timers.tick(5000)
  assert.equal(vm.elapsedTime, '01:00:00')
})

// Le formulaire de départ oublié partage les mêmes services HTTP que le pointage.
function completionComponent(now = new Date()) {
  const vm = { ...MissingDeparture.data(), userId: 12, now, tableRow: false, weekStart: null, events: [] }
  vm.$emit = (event) => vm.events.push(event)
  for (const [name, getter] of Object.entries(MissingDeparture.computed)) {
    Object.defineProperty(vm, name, { get: () => getter.call(vm) })
  }
  for (const [name, method] of Object.entries(MissingDeparture.methods)) vm[name] = method.bind(vm)
  return vm
}

function overdueArrival(now = new Date()) {
  return { id: 101, time: formatClockDate(new Date(now.getTime() - 2 * 86400000)), status: true, kind: 'arrival' }
}

test('missing departure waits 24 hours, including overnight shifts, and disappears after departure', () => {
  const now = new Date('2026-10-05T08:00:00Z')
  const arrival = { id: 1, time: '2026-10-04 23:00:00', status: true, kind: 'arrival' }
  assert.equal(findMissingDeparture([arrival], now), null)
  arrival.time = '2026-10-04 08:00:01'
  assert.equal(findMissingDeparture([arrival], now), null)
  arrival.time = '2026-10-04 08:00:00'
  assert.equal(findMissingDeparture([arrival], now).arrival.id, 1)
  const departure = { id: 2, time: '2026-10-04 17:00:00', status: false, kind: 'departure' }
  assert.equal(findMissingDeparture([arrival, departure], now), null)
  assert.equal(findMissingDeparture([], now), null)
})

test('an overdue service stays detectable during a pause or after resuming', () => {
  const now = new Date('2026-10-05T08:00:00Z')
  const arrival = overdueArrival(now)
  const pause = { id: 102, time: '2026-10-05 07:00:00', status: false, kind: 'pause' }
  assert.equal(findMissingDeparture([arrival, pause], now).last.id, pause.id)
  const resume = { id: 103, time: '2026-10-05 07:30:00', status: true, kind: 'resume' }
  const result = findMissingDeparture([arrival, pause, resume], now)
  assert.equal(result.arrival.id, arrival.id)
  assert.equal(result.last.id, resume.id)
})

test('completion validates empty, future, early and expired local dates', () => {
  const now = new Date('2026-10-05T08:00:00Z')
  const arrival = overdueArrival(now)
  assert.match(departureError('', arrival, now), /Indiquez/)
  assert.match(departureError('nonsense', arrival, now), /invalide/)
  assert.match(departureError(localDateInput(new Date(now.getTime() + 1000)), arrival, now), /futur/)
  assert.match(departureError(localDateInput(new Date('2026-10-03T08:00:00Z')), arrival, now), /suivre/)
  assert.match(departureError(localDateInput(new Date('2026-09-20T08:00:00Z')), arrival, now), /7 derniers jours/)
  const finish = new Date('2026-10-03T17:00:12Z')
  assert.equal(departureError(localDateInput(finish), arrival, now), '')
  assert.equal(formatClockDate(new Date(localDateInput(finish))), '2026-10-03 17:00:12')
})

test('local date validation rejects the missing hour at the Paris spring transition', () => {
  const oldTZ = process.env.TZ
  try {
    process.env.TZ = 'Europe/Paris'
    const arrival = { id: 1, time: '2026-03-28 08:00:00', status: true }
    assert.match(departureError('2026-03-29T02:30:00', arrival, new Date('2026-03-29T10:00:00Z')), /invalide/)
    assert.equal(formatClockDate(new Date('2026-03-29T03:30:00')), '2026-03-29 01:30:00')
  } finally {
    if (oldTZ === undefined) delete process.env.TZ
    else process.env.TZ = oldTZ
  }
})

test('completion sends the last event identifier and real UTC time, then clears the alert', async () => {
  const now = new Date()
  const entries = [overdueArrival(now)]
  const finish = new Date(now.getTime() - 86400000)
  let posts = 0
  globalThis.fetch = async (url, options) => {
    if (options.method === 'POST') {
      posts += 1
      assert.equal(url, '/api/clocks/12/101/complete')
      assert.deepEqual(JSON.parse(options.body), { clock: { time: formatClockDate(finish) } })
      const clock = { id: 102, time: formatClockDate(finish), status: false, kind: 'departure' }
      entries.push(clock)
      return response(clock, 201)
    }
    assert.equal(url, '/api/clocks/12')
    return response([...entries])
  }
  const vm = completionComponent(now)
  await vm.refresh()
  assert.equal(vm.visible, true)
  assert.equal(vm.finish, '')
  vm.finish = localDateInput(finish)
  await vm.submit()
  assert.equal(posts, 1)
  assert.deepEqual(vm.events, ['completed'])
  assert.equal(vm.visible, false)
  assert.equal(vm.missing, null)
  assert.equal(vm.saving, false)
})

test('completion blocks a double click while saving and local errors never send a POST', async () => {
  const vm = completionComponent()
  vm.clocks = [overdueArrival()]
  let posts = 0
  const pending = deferred()
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') { posts += 1; return pending.promise }
    return response([])
  }
  await vm.submit()
  assert.match(vm.error, /Indiquez/)
  assert.equal(posts, 0)
  vm.finish = localDateInput(new Date(Date.now() - 86400000))
  const first = vm.submit()
  await vm.submit()
  assert.equal(posts, 1)
  pending.resolve(response({}, 201))
  await first
  assert.equal(vm.saving, false)
})

test('lost completion response requires a read before retry and refreshes the parent totals', async () => {
  const entries = [overdueArrival()]
  let posts = 0
  globalThis.fetch = async (_url, options) => {
    if (options.method === 'POST') {
      posts += 1
      entries.push({ id: 102, time: JSON.parse(options.body).clock.time, status: false, kind: 'departure' })
      throw new Error('Saved but response lost')
    }
    return response([...entries])
  }
  const vm = completionComponent()
  await vm.refresh()
  vm.finish = localDateInput(new Date(Date.now() - 86400000))
  await vm.submit()
  assert.equal(vm.needsRefresh, true)
  assert.deepEqual(vm.events, [])
  await vm.submit()
  assert.equal(posts, 1)
  await vm.refresh()
  assert.equal(vm.visible, false)
  assert.deepEqual(vm.events, ['refreshed'])
})

test('server rejection explains stale pointages and blocks another completion', async () => {
  let posts = 0
  const vm = completionComponent()
  vm.clocks = [overdueArrival()]
  vm.finish = localDateInput(new Date(Date.now() - 86400000))
  globalThis.fetch = async () => {
    posts += 1
    return { ok: false, status: 422, json: async () => ({ errors: { time: ['Les pointages ont changé. Actualisez avant de réessayer.'] } }) }
  }
  await vm.submit()
  await vm.submit()
  assert.match(vm.error, /Actualisez/)
  assert.equal(vm.needsRefresh, true)
  assert.equal(posts, 1)
  assert.deepEqual(vm.events, [])
})

test('a failed or malformed clock read displays an error, never a correction for guessed data', async () => {
  const vm = completionComponent()
  for (const data of [null, [{ id: 1, time: 'invalid', status: true }]]) {
    globalThis.fetch = async () => response(data)
    await vm.refresh()
    assert.equal(vm.missing, null)
    assert.equal(vm.needsRefresh, true)
    assert.ok(vm.error)
  }
})

test('a late completion history cannot overwrite the newly selected user', async () => {
  const pending = deferred()
  const vm = completionComponent()
  globalThis.fetch = () => pending.promise
  const old = vm.refresh()
  vm.userId = 13
  globalThis.fetch = async () => response([])
  await vm.refresh()
  pending.resolve(response([overdueArrival()]))
  await old
  assert.equal(vm.visible, false)
})

test('the week table alert is restricted to the selected week', () => {
  const vm = completionComponent(new Date('2026-10-05T10:00:00Z'))
  vm.clocks = [overdueArrival(vm.now)]
  vm.weekStart = new Date('2026-09-28T00:00:00')
  assert.equal(vm.visible, true)
  vm.weekStart = new Date('2026-10-05T00:00:00')
  assert.equal(vm.visible, false)
})

test('completing from home refreshes the clock; completing from hours reloads the selected list', async () => {
  let clockReads = 0
  const homeEvents = []
  EmployeeToday.methods.onDepartureCompleted.call({
    $refs: { clockManager: { refresh() { clockReads += 1 } } },
    $emit: (event) => homeEvents.push(event),
  })
  assert.equal(clockReads, 1)
  assert.deepEqual(homeEvents, ['changed'])
  const period = { start: '2026-10-03 09:00:00', end: '2026-10-03 17:00:00' }
  const list = { userId: 12, filters: { start: '2026-09-28 00:00:00' }, events: [] }
  list.$emit = (event) => list.events.push(event)
  list.getWorkingTimes = WorkingTimes.methods.getWorkingTimes.bind(list)
  globalThis.fetch = async (url) => {
    assert.equal(new URL(url, 'http://localhost').searchParams.get('start'), list.filters.start)
    return response([period])
  }
  await WorkingTimes.methods.onDepartureCompleted.call(list)
  assert.deepEqual(list.workingTimes, [period])
  assert.deepEqual(list.events, ['changed'])
})

function managerComponent() {
  const vm = { ...TeamOverview.data(), now: new Date('2026-10-05T10:00:00Z'), monday: new Date('2026-09-28T00:00:00') }
  for (const [name, getter] of Object.entries(TeamOverview.computed)) {
    Object.defineProperty(vm, name, { get: () => getter.call(vm) })
  }
  for (const [name, method] of Object.entries(TeamOverview.methods)) vm[name] = method.bind(vm)
  return vm
}

function teamApi({ histories = {}, errors = [], missing = [], periods = {} } = {}) {
  const users = team().members.filter((member) => !missing.includes(member.username))
    .map((member, index) => ({ id: 800 + index, username: member.username, email: `${member.username}@example.test` }))
  const requests = []
  globalThis.fetch = async (url, options) => {
    assert.equal(options.method || 'GET', 'GET')
    requests.push(url)
    const path = new URL(url, 'http://localhost').pathname
    if (path === '/api/users') return response(users)
    const user = users.find((item) => path.endsWith(`/${item.id}`))
    assert.ok(user, `Unexpected user in ${url}`)
    if (path.startsWith('/api/clocks/')) {
      if (errors.includes(user.username)) return response(null, 503)
      return response(histories[user.username] || [])
    }
    if (path.startsWith('/api/workingtime/')) return response(periods[user.username] || [])
    throw new Error(`Unexpected route ${url}`)
  }
  return { users, requests }
}

const managerArrival = { id: 101, time: '2026-10-03 09:00:12', status: true, kind: 'arrival' }

test('manager loads actual team clocks and excludes missing departures from clean sheets', async () => {
  const { users, requests } = teamApi({ histories: { 'sara.ortiz': [managerArrival] } })
  const vm = managerComponent()
  await vm.loadTeam()
  assert.equal(vm.error, '')
  assert.deepEqual(vm.departureAlerts.map((row) => row.username), ['sara.ortiz'])
  assert.equal(vm.departureAlerts[0].user.id, users.find((user) => user.username === 'sara.ortiz').id)
  assert.equal(vm.departureAlerts[0].missingDeparture.arrival.time, managerArrival.time)
  assert.equal(vm.departureAlerts[0].departureInWeek, true)
  assert.equal(vm.sortedRows[0].username, 'sara.ortiz')
  assert.equal(vm.selection.includes('sara.ortiz'), false)
  vm.toggle('sara.ortiz')
  assert.equal(vm.selection.includes('sara.ortiz'), false)
  assert.equal(vm.cleanRows.length, team().members.length - 1)
  assert.equal(requests.filter((url) => url.startsWith('/api/clocks/')).length, users.length)
})

test('manager refresh removes the alert after the employee completes the departure', async () => {
  const clocks = [managerArrival]
  teamApi({ histories: { 'sara.ortiz': clocks } })
  const vm = managerComponent()
  await vm.loadTeam()
  assert.equal(vm.departureAlerts.length, 1)
  clocks.push({ id: 102, time: '2026-10-03 17:00:12', status: false, kind: 'departure' })
  const period = { id: 1, start: managerArrival.time, end: '2026-10-03 17:00:12' }
  teamApi({ histories: { 'sara.ortiz': clocks }, periods: { 'sara.ortiz': [period] } })
  await vm.loadTeam()
  assert.equal(vm.departureAlerts.length, 0)
  assert.equal(vm.selection.includes('sara.ortiz'), true)
  assert.equal(vm.rows.find((row) => row.username === 'sara.ortiz').buckets.total, 8)
})

test('manager keeps other alerts when one clock request fails and reports absent profiles', async () => {
  teamApi({ histories: { 'sara.ortiz': [managerArrival] }, errors: ['marie.dubois'], missing: ['paula.ibanez'] })
  const vm = managerComponent()
  await vm.loadTeam()
  assert.equal(vm.error, '')
  assert.equal(vm.departureAlerts.length, 1)
  assert.equal(vm.clockProblems.length, 2)
  assert.match(vm.clockProblems.join(' '), /Marie D.*pointages indisponibles/)
  assert.match(vm.clockProblems.join(' '), /Paula I.*profil absent/)
  for (const username of ['marie.dubois', 'paula.ibanez']) {
    assert.equal(vm.selection.includes(username), false)
    vm.toggle(username)
    assert.equal(vm.selection.includes(username), false)
  }
})

test('invalid clocks and failed user reads cannot make a sheet appear verified', async () => {
  teamApi({ histories: { 'sara.ortiz': [{ ...managerArrival, time: 'not-a-date' }] } })
  const vm = managerComponent()
  await vm.loadTeam()
  assert.equal(vm.departureAlerts.length, 0)
  assert.equal(vm.clockProblems.length, 1)
  assert.equal(vm.selection.includes('sara.ortiz'), false)
  globalThis.fetch = async () => response(null)
  await vm.loadTeam()
  assert.match(vm.error, /utilisateurs invalide/)
  assert.equal(vm.loading, false)
  assert.deepEqual(vm.selection, [])
})

test('manager draft uses the API email, encoded text and real arrival without sending anything', async () => {
  const { requests } = teamApi({ histories: { 'sara.ortiz': [managerArrival] } })
  const vm = managerComponent()
  await vm.loadTeam()
  const row = vm.departureAlerts[0]
  row.user.email = 'sara+clock@example.test'
  row.name = 'Sara & Équipe'
  const count = requests.length
  const link = new URL(vm.departureMail(row))
  assert.equal(link.protocol, 'mailto:')
  assert.equal(decodeURIComponent(link.pathname), 'sara+clock@example.test')
  assert.equal(link.searchParams.get('subject'), 'Time Manager — heure de départ à compléter')
  assert.ok(link.searchParams.get('body').includes(vm.arrivalLabel(row)))
  assert.ok(link.searchParams.get('body').includes('Bonjour Sara & Équipe,'))
  assert.match(link.searchParams.get('body'), /confirmer la date et l’heure réelles/)
  assert.equal(requests.length, count)
  for (const email of ['', 'not-an-email', 'sara@example.test\r\nBcc:another@example.test', null, 123]) {
    row.user.email = email
    assert.equal(vm.departureMail(row), '')
  }
})

test('an open overnight service under 24 hours does not produce a manager alert', async () => {
  teamApi({ histories: { 'sara.ortiz': [{ ...managerArrival, time: '2026-10-04 23:00:00' }] } })
  const vm = managerComponent()
  await vm.loadTeam()
  assert.equal(vm.departureAlerts.length, 0)
  assert.equal(vm.selection.includes('sara.ortiz'), true)
})

test('manager alerts survive a pause and block only the week containing the arrival', async () => {
  const pause = { id: 102, time: '2026-10-03 12:00:00', status: false, kind: 'pause' }
  teamApi({ histories: { 'sara.ortiz': [managerArrival, pause] } })
  const vm = managerComponent()
  await vm.loadTeam()
  assert.equal(vm.departureAlerts.length, 1)
  assert.equal(vm.canSelect(vm.departureAlerts[0]), false)
  vm.monday = new Date('2026-10-05T00:00:00')
  assert.equal(vm.departureAlerts.length, 1)
  assert.equal(vm.departureAlerts[0].departureInWeek, false)
  assert.equal(vm.canSelect(vm.departureAlerts[0]), true)
})

test('crossing the 24-hour threshold drops an already selected incomplete sheet', async () => {
  teamApi({ histories: { 'sara.ortiz': [{ ...managerArrival, time: '2026-10-04 11:00:00' }] } })
  const vm = managerComponent()
  await vm.loadTeam()
  assert.equal(vm.selection.includes('sara.ortiz'), true)
  vm.now = new Date('2026-10-05T11:00:01Z')
  TeamOverview.watch.rows.call(vm)
  assert.equal(vm.selection.includes('sara.ortiz'), false)
})

test('manager ignores pending results after leaving and prevents overlapping refreshes', async () => {
  const pending = deferred()
  let requests = 0
  globalThis.fetch = async () => { requests += 1; return pending.promise }
  const vm = managerComponent()
  const first = vm.loadTeam()
  await vm.loadTeam()
  assert.equal(requests, 1)
  TeamOverview.beforeUnmount.call(vm)
  pending.resolve(response([]))
  await first
  assert.deepEqual(vm.clockErrors, {})
  assert.deepEqual(vm.selection, [])
})

test('validation rechecks selected sheets so a missing departure cannot be bypassed', async () => {
  const previous = { ...org.validated }
  try {
    teamApi({ histories: { 'sara.ortiz': [managerArrival] } })
    const vm = managerComponent()
    await vm.loadTeam()
    vm.selection = ['sara.ortiz']
    vm.validate()
    assert.equal(isValidated('sara.ortiz', vm.weekKey), false)
    assert.equal(vm.departureAlerts.length, 1)
  } finally {
    org.validated = previous
  }
})
