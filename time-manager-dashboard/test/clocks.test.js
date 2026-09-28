import assert from 'node:assert/strict'
import { after, before, beforeEach, test } from 'node:test'
import { createServer } from 'vite'

let server
let ClockManager
let App
let WorkingTimes
let durationInHours
let formatClockDate
let mockListClocks
let mockCreateClock
const originalFetch = globalThis.fetch

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
  Object.defineProperty(vm, 'loading', { get: () => ClockManager.computed.loading.call(vm) })
  for (const [name, method] of Object.entries(ClockManager.methods)) vm[name] = method.bind(vm)
  return vm
}

before(async () => {
  server = await createServer({ server: { middlewareMode: true, hmr: false }, appType: 'custom' })
  ClockManager = (await server.ssrLoadModule('/src/components/ClockManager.vue')).default
  App = (await server.ssrLoadModule('/src/App.vue')).default
  WorkingTimes = (await server.ssrLoadModule('/src/components/WorkingTimes.vue')).default
  ;({ durationInHours } = await server.ssrLoadModule('/src/utils/date.js'))
  ;({ formatClockDate } = await server.ssrLoadModule('/src/utils/clockDate.js'))
  ;({ mockListClocks, mockCreateClock } = await server.ssrLoadModule('/src/mocks/clocks.js'))
})

beforeEach(() => {
  globalThis.fetch = async () => { throw new Error('Unexpected HTTP request') }
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

test('UTC date convention handles offsets, space format and invalid dates', () => {
  assert.equal(formatClockDate('2026-09-24T11:00:00+02:00'), '2026-09-24 09:00:00')
  assert.equal(formatClockDate('2026-09-24 09:00:00'), '2026-09-24 09:00:00')
  assert.throws(() => formatClockDate('not-a-date'))
  assert.throws(() => formatClockDate(null))
})

test('simulator stores the requested status/time with stable ordering for identical seconds', () => {
  const attrs = { time: '2099-01-01 09:00:00', status: true }
  mockCreateClock(700, attrs)
  mockCreateClock(700, { ...attrs, status: false })
  const entries = mockListClocks(700)
  assert.equal(entries.at(-1).status, false)
  assert.equal(entries.at(-1).time, attrs.time)
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

test('clock route events reload totals when the overview list is not mounted', async () => {
  globalThis.fetch = async (url) => {
    assert.equal(url, '/api/workingtime/12')
    return response([{ start: '2026-09-28 09:00:00', end: '2026-09-28 17:00:00' }])
  }
  const vm = { ...App.data(), userId: 12, $route: { name: 'clock' }, $refs: {} }
  for (const [name, method] of Object.entries(App.methods)) vm[name] = method.bind(vm)
  const listeners = App.computed.routeListeners.call(vm)
  await listeners.onChanged()
  assert.equal(App.computed.totalHours.call(vm), 8)
  assert.equal(vm.workingTimes.length, 1)
})

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
