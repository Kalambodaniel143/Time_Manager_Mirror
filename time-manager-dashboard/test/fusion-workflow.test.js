import assert from 'node:assert/strict'
import { webcrypto } from 'node:crypto'
import { after, before, beforeEach, test } from 'node:test'
import { createServer } from 'vite'

let server, demo, work, corrections
const values = new Map()
const originalFetch = globalThis.fetch
const password = 'Password8'
const profile = email => ({ first_name: 'Sara', last_name: 'Martin', email, gender: 'female', birth_date: '1999-03-12', birth_place: 'Paris' })
const minutesAgo = value => new Date(Date.now() - value * 60000)

before(async () => {
  globalThis.localStorage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, String(value)), removeItem: key => values.delete(key) }
  globalThis.sessionStorage = globalThis.localStorage
  if (!globalThis.crypto) globalThis.crypto = webcrypto
  server = await createServer({ configFile: false, server: { middlewareMode: true, hmr: false }, appType: 'custom', define: { 'import.meta.env.VITE_AUTH_USE_MOCK': JSON.stringify('false'), 'import.meta.env.VITE_USE_MOCK': JSON.stringify('false') } })
  demo = await server.ssrLoadModule('/src/mocks/organizationAuth.js')
  work = await server.ssrLoadModule('/src/mocks/organizationWork.js')
  corrections = await server.ssrLoadModule('/src/services/correctionService.js')
})
beforeEach(() => values.clear())
after(async () => { globalThis.fetch = originalFetch; await server.close() })

async function organization(email = 'admin@example.com', name = 'Atelier') {
  return demo.mockCreateOrganization({ name, profile: profile(email), password })
}
async function employee(org) {
  demo.mockLogout()
  const request = demo.mockJoinOrganization({ organization_id: org.organization.id, profile: profile('worker@example.com') })
  await demo.mockLogin({ email: org.user.email, password })
  const pending = demo.mockListRequests(org.organization.id).find(item => item.profile.email === 'worker@example.com')
  await demo.mockApproveRequest(org.organization.id, pending.id, password)
  assert.equal(demo.mockRequestStatus(request.reference).status, 'approved')
  return demo.mockLogin({ email: 'worker@example.com', password })
}
function completedService(userId) {
  work.workClock(userId, { time: minutesAgo(120), kind: 'arrival', status: true })
  work.workClock(userId, { time: minutesAgo(90), kind: 'pause', status: false })
  work.workClock(userId, { time: minutesAgo(60), kind: 'resume', status: true })
  work.workClock(userId, { time: minutesAgo(30), kind: 'departure', status: false })
}

test('demo pointages persist, exclude pauses and reject stale/future transitions atomically', async () => {
  const org = await organization()
  completedService(org.user.id)
  const periods = work.workPeriods(org.user.id)
  assert.equal(periods.length, 2)
  assert.equal(Math.round(periods.reduce((sum, item) => sum + (Date.parse(item.end.replace(' ', 'T') + 'Z') - Date.parse(item.start.replace(' ', 'T') + 'Z')) / 60000, 0)), 60)
  assert.throws(() => work.workClock(org.user.id, { time: minutesAgo(-5), kind: 'arrival', status: true }), /futur/)
  const arrival = work.workClock(org.user.id, { time: minutesAgo(10), kind: 'arrival', status: true })
  assert.throws(() => work.workClock(org.user.id, { time: minutesAgo(5), kind: 'departure', status: false }, arrival.id - 1), /changé/)
  assert.equal(work.workClocks(org.user.id).length, 5)
  assert.equal(work.workPeriods(org.user.id).length, 2)
  demo.mockLogout(); await demo.mockLogin({ email: org.user.email, password })
  assert.equal(work.workClocks(org.user.id).length, 5)
})

test('proposals do not overwrite worked hours; only another authorized reviewer can approve once', async () => {
  const org = await organization(), worker = await employee(org)
  completedService(worker.user.id)
  const period = work.workPeriods(worker.user.id)[0]
  const proposal = work.workRequestCorrection(period.id, { start: period.start, end: period.end, reason: 'Confirmer les horaires' })
  assert.equal(work.workPeriods(worker.user.id)[0].end, period.end)
  assert.throws(() => work.workUpdatePeriod(period.id, { start: period.start, end: period.end }), /droits/)
  assert.throws(() => work.workRequestCorrection(period.id, { start: period.start, end: period.end, reason: 'Deuxième demande' }), /déjà en attente/)
  assert.throws(() => work.workReviewCorrection(proposal.id, 'approved'), /propre correction/)
  await demo.mockLogin({ email: org.user.email, password })
  work.workReviewCorrection(proposal.id, 'approved', 'Horaires vérifiés')
  assert.equal(work.workCorrections()[0].status, 'approved')
  assert.equal(work.workCorrections()[0].reviewed_by, org.user.username)
  assert.throws(() => work.workReviewCorrection(proposal.id, 'approved'), /déjà été traitée/)
})

test('rejections require a reason and preserve original hours; changed periods cannot accept stale proposals', async () => {
  const org = await organization(), worker = await employee(org)
  completedService(worker.user.id)
  const period = work.workPeriods(worker.user.id)[0]
  const proposal = work.workRequestCorrection(period.id, { start: period.start, end: period.end, reason: 'Vérification' })
  await demo.mockLogin({ email: org.user.email, password })
  assert.throws(() => work.workReviewCorrection(proposal.id, 'rejected'), /motif/)
  work.workReviewCorrection(proposal.id, 'rejected', 'Une précision est nécessaire')
  assert.equal(work.workPeriods(worker.user.id)[0].end, period.end)
  assert.equal(work.workCorrections()[0].review_reason, 'Une précision est nécessaire')
  await demo.mockLogin({ email: worker.user.email, password })
  const second = work.workRequestCorrection(period.id, { start: period.start, end: period.end, reason: 'Précision' })
  await demo.mockLogin({ email: org.user.email, password })
  const end = new Date(Date.parse(period.end.replace(' ', 'T') + 'Z') + 60000).toISOString().slice(0, 19).replace('T', ' ')
  work.workUpdatePeriod(period.id, { start: period.start, end })
  assert.throws(() => work.workReviewCorrection(second.id, 'approved'), /horaires ont changé/)
})

test('organization workspaces cannot read, change or review another organization data', async () => {
  const first = await organization()
  completedService(first.user.id)
  const period = work.workPeriods(first.user.id)[0]
  work.workRequestCorrection(period.id, { start: period.start, end: period.end, reason: 'Vérifier' })
  await organization('other@example.com', 'Autre atelier')
  assert.throws(() => work.workPeriods(first.user.id), /droits/)
  assert.throws(() => work.workClock(first.user.id, { time: minutesAgo(1), kind: 'arrival', status: true }), /vous-même/)
  assert.equal(work.workCorrections().length, 0)
})

test('real correction service matches documented routes, sends JSON and uses the shared CSRF transport', async () => {
  const { auth } = await server.ssrLoadModule('/src/stores/auth.js')
  const { configureHttp } = await server.ssrLoadModule('/src/services/http.js')
  auth.organizationSession = null; auth.csrfToken = 'csrf-example'
  configureHttp({ csrfToken: () => auth.csrfToken })
  const calls = []
  globalThis.fetch = async (url, options) => {
    calls.push({ url, ...options })
    const period = { start: '2026-10-06 08:00:00', end: '2026-10-06 16:00:00' }
    const item = { id: 7, period_id: 23, user_id: 14, username: 'sara@example.com', reason: 'Intervention prolongée', before: period, proposal: period, status: options.method === 'PATCH' ? 'rejected' : 'pending' }
    return { ok: true, status: 200, json: async () => ({ data: options.method ? item : [item] }) }
  }
  await corrections.listCorrections(14)
  const attrs = { start: '2026-10-06 08:00:00', end: '2026-10-06 16:00:00', reason: 'Intervention prolongée' }
  await corrections.requestCorrection(23, attrs)
  await corrections.reviewCorrection(7, 'rejected', 'Précisez votre départ')
  assert.deepEqual(calls.map(call => call.url), ['/api/correction-requests?user_id=14', '/api/workingtime/23/correction-requests', '/api/correction-requests/7'])
  assert.deepEqual(JSON.parse(calls[1].body), { correction: attrs })
  assert.deepEqual(JSON.parse(calls[2].body), { status: 'rejected', reason: 'Précisez votre départ' })
  assert.equal(calls[2].method, 'PATCH')
  assert.equal(calls[1].headers['X-CSRF-Token'], 'csrf-example')
  assert.equal(calls[1].credentials, 'same-origin')
})


test('correction service never reports success for unavailable or malformed API responses', async () => {
  const { auth } = await server.ssrLoadModule('/src/stores/auth.js')
  auth.organizationSession = null
  globalThis.fetch = async () => ({ ok: false, status: 404, json: async () => ({ errors: { detail: 'Not available' } }) })
  await assert.rejects(corrections.requestCorrection(23, {}), error => error.status === 404)
  globalThis.fetch = async () => ({ ok: true, status: 200, json: async () => ({ data: {} }) })
  await assert.rejects(corrections.listCorrections(14), /Liste.*invalide/)
  await assert.rejects(corrections.requestCorrection(23, {}), /Réponse.*invalide/)
})
