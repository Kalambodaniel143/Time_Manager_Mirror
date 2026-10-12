import assert from 'node:assert/strict'
import { before, after, beforeEach, test } from 'node:test'
import { createServer } from 'vite'
import { rewriteLocalOrigin } from '../dev/apiProxy.js'

let server, store, org, reports, accounts, periods, TeamOverview, CorrectionPanel
const originalFetch = globalThis.fetch
const values = new Map([['tm-org', JSON.stringify({ notes: { old: 'ancienne note' }, validated: { old: true }, rights: [{ name: 'Personne fictive' }] })]])
const user = { id: 17, role: 'administrator', username: 'admin', email: 'admin@example.test', first_name: null, last_name: null, organization_id: null }

before(async () => {
  globalThis.localStorage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, String(value)), removeItem: key => values.delete(key) }
  globalThis.sessionStorage = globalThis.localStorage
  server = await createServer({ server: { middlewareMode: true, hmr: false }, appType: 'custom', define: { 'import.meta.env.VITE_AUTH_USE_MOCK': JSON.stringify('false'), 'import.meta.env.VITE_USE_MOCK': JSON.stringify('true') } })
  store = await server.ssrLoadModule('/src/stores/auth.js')
  org = await server.ssrLoadModule('/src/services/orgService.js')
  reports = await server.ssrLoadModule('/src/services/reportService.js')
  accounts = await server.ssrLoadModule('/src/services/userService.js')
  periods = await server.ssrLoadModule('/src/services/workingTimeService.js')
  TeamOverview = (await server.ssrLoadModule('/src/views/TeamOverview.vue')).default
  CorrectionPanel = (await server.ssrLoadModule('/src/components/reviews/CorrectionPanel.vue')).default
  const { configureHttp } = await server.ssrLoadModule('/src/services/http.js')
  configureHttp({ csrfToken: () => store.auth.csrfToken })
})
beforeEach(() => {
  store.clearSession(); store.auth.user = { ...user }; store.auth.csrfToken = 'test-csrf'
  globalThis.fetch = async () => { throw new Error('Unexpected HTTP request') }
})
after(async () => { globalThis.fetch = originalFetch; await server.close() })

const response = (data, status = 200) => ({ ok: status < 400, status, json: async () => ({ data }) })

test('legacy login accepts a real account without inventing a Gotham membership; role mismatches still fail', async () => {
  globalThis.fetch = async () => response({ role: 'administrator', user, organization: null, csrf_token: 'test-csrf' })
  await store.login(user.email, 'Password8')
  assert.equal(store.auth.user.id, 17)
  assert.equal(store.auth.user.role, 'administrator')
  assert.equal(store.auth.organization, null)
  assert.equal(store.auth.organizationSession, null)
  globalThis.fetch = async () => response({ role: 'administrator', user: { ...user, organization_id: 'fake' }, organization: null, csrf_token: 'test-csrf' })
  await assert.rejects(store.login(user.email, 'Password8'), /session invalide/)
  globalThis.fetch = async () => response({ role: 'manager', user, organization: null, csrf_token: 'test-csrf' })
  await assert.rejects(store.login(user.email, 'Password8'), /session invalide/)
})

test('real sessions ignore historical demo data and never persist local business actions', () => {
  assert.equal(org.isDemoData(), false)
  assert.deepEqual(org.team().members, [])
  assert.deepEqual(org.employeePlan(), [])
  assert.deepEqual(org.payroll().rows, [])
  assert.deepEqual(org.org.rights, [])
  assert.deepEqual(org.org.notes, {})
  assert.deepEqual(org.org.validated, {})
  const saved = values.get('tm-org')
  assert.throws(() => org.setNote('admin', '2026-10-12', 'test'), /mode réel/)
  assert.throws(() => org.validateSheets(['admin'], '2026-10-12'), /mode réel/)
  assert.equal(values.get('tm-org'), saved)
  assert.deepEqual(org.org.notes, {})
})

test('real authenticated user routes use the API even with a stale global mock flag', async () => {
  const calls = []
  globalThis.fetch = async (url, options) => { calls.push(url); assert.equal(options.headers['X-CSRF-Token'], 'test-csrf'); return response([]) }
  await accounts.listUsers(); await periods.getWorkingTimes(user.id)
  assert.deepEqual(calls, ['/api/users', '/api/workingtime/17'])
  globalThis.fetch = async () => response(null, 503)
  await assert.rejects(accounts.listUsers(), error => error.status === 503)
  await assert.rejects(periods.getWorkingTimes(user.id), error => error.status === 503)
})

test('monthly durations clip cross-month services and remain exact across a daylight-saving boundary', () => {
  const entries = [
    { start: '2026-09-30 22:00:00', end: '2026-10-01 02:00:00' },
    { start: '2026-10-25 00:00:00', end: '2026-10-25 03:00:00' },
    { start: '2026-10-31 22:00:00', end: '2026-11-01 02:00:00' },
  ]
  assert.equal(reports.hoursBetween(entries, new Date(2026, 9, 1), new Date(2026, 10, 1)), 7)
  const days = reports.dailyHours(entries, new Date(2026, 8, 28))
  assert.equal(days[2].hours, 2); assert.equal(days[3].hours, 2)
  assert.throws(() => reports.hoursBetween([{ start: 'bad', end: 'bad' }], new Date(2026, 9, 1), new Date(2026, 10, 1)))
})

test('monthly reports deduplicate users across teams and reject partial server failures', async () => {
  const paths = []
  globalThis.fetch = async url => {
    paths.push(url)
    if (url === '/api/users') return response([user, user])
    if (url === '/api/workforce/context') return response({ rules: { maxConsecutiveNights: 3, maxNightsPerWeek: 0, maxNightsPerMonth: 0, overtimeThreshold: 40 }, preferences: {}, permissions: [{team_id:1,manager_id:99,validate:false,correct:true,publish:false}] })
    if (url.startsWith('/api/weekly-sheets')) return response([])
    if (url === '/api/teams') return response([{ id: 1, name: 'Première', members: [user] }, { id: 2, name: 'Seconde', members: [user] }])
    assert.equal(url, '/api/workingtime/17')
    return response([{ start: '2026-10-03 08:00:00', end: '2026-10-03 10:30:00' }])
  }
  const report = await reports.monthlyReport(new Date(2026, 9, 1))
  assert.equal(report.rows.length, 1); assert.equal(report.total, 2.5)
  assert.equal(report.rows[0].teams, 'Première, Seconde')
  assert.equal(paths.filter(path => path.includes('workingtime')).length, 1)
  globalThis.fetch = async url => url.includes('workingtime') ? response(null, 503) : response(url === '/api/users' ? [user] : [])
  await assert.rejects(reports.monthlyReport(new Date(2026, 9, 1)), error => error.status === 503)
})

test('CSV quotes personal labels and prevents spreadsheet formulas', () => {
  const csv = reports.reportCsv({ rows: [{ name: '=1+1', email: 'a"b@example.test', teams: 'Une;Deux', total: 2.5 }] })
  assert.ok(csv.includes('"\'=1+1"')); assert.ok(csv.includes('"a""b@example.test"')); assert.ok(csv.includes('"Une;Deux"')); assert.ok(csv.includes('"2,50"'))
})

test('only managed teams populate the overview; effective server permissions control validation', async () => {
  store.auth.user = { id: 99, role: 'manager', username: 'manager' }
  const calls = []
  globalThis.fetch = async url => {
    calls.push(url)
    if (url === '/api/workforce/context') return response({ rules: { maxConsecutiveNights: 3, maxNightsPerWeek: 0, maxNightsPerMonth: 0, overtimeThreshold: 40 }, preferences: {}, permissions: [{team_id:1,manager_id:99,validate:false,correct:true,publish:false}] })
    if (url.startsWith('/api/weekly-sheets')) return response([])
    if (url === '/api/teams') return response([{ id: 1, name: 'Mon équipe', manager: { id: 99 }, members: [{ ...user, role: 'employee' }] }, { id: 2, name: 'Autre équipe', manager: { id: 98 }, members: [{ id: 20, username: 'foreign' }] }])
    assert.ok(url.includes('/17'))
    return response([])
  }
  const vm = { ...TeamOverview.data(), now: new Date() }
  for (const [name, getter] of Object.entries(TeamOverview.computed)) Object.defineProperty(vm, name, { get: () => getter.call(vm) })
  for (const [name, method] of Object.entries(TeamOverview.methods)) vm[name] = method.bind(vm)
  await vm.loadTeam()
  assert.equal(vm.error, ''); assert.equal(vm.teams.length, 1); assert.equal(vm.rows.length, 1)
  assert.equal(vm.teamName, 'Mon équipe'); assert.deepEqual(vm.selection, [])
  vm.selection = ['admin']; vm.validate(); assert.deepEqual(org.org.validated, {})
  let correctionReads = 0
  CorrectionPanel.watch.userId.handler.call({ demo: false, load() { correctionReads += 1 } })
  assert.equal(correctionReads, 1)
  assert.equal(calls.some(url => url.includes('correction-requests')), false)
})

test('dev proxy rewrites its own browser origin but preserves a hostile origin', () => {
  const headers = {}, proxy = { setHeader: (key, value) => { headers[key] = value } }
  rewriteLocalOrigin(proxy, { headers: { host: 'localhost:5173', origin: 'http://localhost:5173', referer: 'http://localhost:5173/connexion' } }, 'http://34.155.104.175:4000')
  assert.equal(headers.origin, 'http://34.155.104.175:4000')
  assert.equal(headers.referer, 'http://34.155.104.175:4000/connexion')
  const foreign = {}
  rewriteLocalOrigin({ setHeader: (key, value) => { foreign[key] = value } }, { headers: { host: 'localhost:5173', origin: 'http://evil.example', referer: 'http://evil.example/' } }, 'http://34.155.104.175:4000')
  assert.deepEqual(foreign, {})
})
