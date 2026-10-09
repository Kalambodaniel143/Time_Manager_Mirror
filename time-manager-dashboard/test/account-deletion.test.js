import assert from 'node:assert/strict'
import { webcrypto } from 'node:crypto'
import { after, before, beforeEach, test } from 'node:test'
import { createServer } from 'vite'

const storage = new Map()
const initialFetch = globalThis.fetch
const password = 'Password8'
const profile = email => ({ first_name: 'Sara', last_name: 'Ortiz', email, gender: 'female', birth_date: '1999-03-12', birth_place: 'Paris' })
let server, demo, work, service, store, Profile
before(async () => {
  globalThis.localStorage = { getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, String(value)), removeItem: key => storage.delete(key) }
  globalThis.sessionStorage = globalThis.localStorage
  if (!globalThis.crypto) globalThis.crypto = webcrypto
  server = await createServer({ server: { middlewareMode: true, hmr: false }, appType: 'custom' })
  demo = await server.ssrLoadModule('/src/mocks/organizationAuth.js')
  work = await server.ssrLoadModule('/src/mocks/organizationWork.js')
  service = await server.ssrLoadModule('/src/services/accountService.js')
  store = await server.ssrLoadModule('/src/stores/auth.js')
  Profile = (await server.ssrLoadModule('/src/components/Profile.vue')).default
  const { configureHttp } = await server.ssrLoadModule('/src/services/http.js')
  configureHttp({ csrfToken: () => store.auth.csrfToken })
})
beforeEach(() => { storage.clear(); store.clearSession() })
after(async () => { globalThis.fetch = initialFetch; await server.close() })
async function fixture() {
  const admin = await demo.mockProvisionSuperAdministrator({ profile: profile('super@gotham.city'), password })
  const receipt = demo.mockJoinOrganization({ organization_id: admin.organization.id, profile: profile('worker@gotham.city') })
  await demo.mockLogin({ email: admin.user.email, password })
  const pending = demo.mockListRequests(admin.organization.id)[0]
  await demo.mockApproveRequest(admin.organization.id, pending.id, password)
  const employee = await demo.mockLogin({ email: 'worker@gotham.city', password })
  store.startOrganizationSession(employee)
  return { admin, employee, receipt }
}

function vm() {
  const instance = { ...Profile.data.call({}), events: [], $emit(name) { this.events.push(name) } }
  Object.entries(Profile.methods).forEach(([name, method]) => { instance[name] = method.bind(instance) })
  return instance
}

test('wrong passwords preserve the mock account and session; successful deletion removes its work only', async () => {
  const { admin, employee } = await fixture()
  const start = new Date(Date.now() - 7200000), end = new Date(Date.now() - 3600000)
  work.workClock(employee.user.id, { time: start, kind: 'arrival', status: true })
  work.workClock(employee.user.id, { time: end, kind: 'departure', status: false })
  const key = `tm-work-demo:${admin.organization.id}`
  const saved = JSON.parse(storage.get(key))
  saved.periods.push({ id: 99, user_id: admin.user.id, start: '2026-01-01 08:00:00', end: '2026-01-01 09:00:00' })
  storage.set(key, JSON.stringify(saved))
  await assert.rejects(service.deleteOwnAccount('incorrect'), error => error.status === 422)
  assert.equal(demo.mockSession().user.id, employee.user.id)
  await service.deleteOwnAccount(password)
  assert.throws(demo.mockSession, error => error.status === 401)
  await assert.rejects(demo.mockLogin({ email: employee.user.email, password }), error => error.status === 401)
  const remaining = JSON.parse(storage.get(key))
  assert.deepEqual(remaining.periods.map(item => item.user_id), [admin.user.id])
  assert.equal(remaining.clocks.length, 0)
  assert.equal((await demo.mockLogin({ email: admin.user.email, password })).user.id, admin.user.id)
})

test('the last super administrator is protected and remains logged in', async () => {
  const admin = await demo.mockProvisionSuperAdministrator({ profile: profile('super@gotham.city'), password })
  await demo.mockLogin({ email: admin.user.email, password })
  await assert.rejects(demo.mockDeleteOwnAccount(password), error => error.status === 409)
  assert.equal(demo.mockSession().user.id, admin.user.id)
})

test('a deleted user ID is never reused by a newly accepted account', async () => {
  const { admin, employee } = await fixture()
  await service.deleteOwnAccount(password)
  const receipt = demo.mockJoinOrganization({ organization_id: admin.organization.id, profile: profile('new@gotham.city') })
  assert.equal(receipt.status, 'pending')
  await demo.mockLogin({ email: admin.user.email, password })
  const pending = demo.mockListRequests(admin.organization.id).find(item => item.profile.email === 'new@gotham.city')
  const result = await demo.mockApproveRequest(admin.organization.id, pending.id, password)
  assert.ok(result.user.id > employee.user.id)
})

test('the actual API uses the signed-in ID, DELETE password body and CSRF header', async () => {
  store.auth.user = { id: 14, username: 'worker', email: 'worker@gotham.city', role: 'employee' }
  store.auth.organizationSession = null
  store.auth.csrfToken = 'csrf-example'
  globalThis.fetch = async (url, options) => {
    assert.equal(url, '/api/users/14')
    assert.equal(options.method, 'DELETE')
    assert.deepEqual(JSON.parse(options.body), { current_password: password })
    assert.equal(options.headers['X-CSRF-Token'], 'csrf-example')
    assert.equal(options.credentials, 'same-origin')
    return { ok: true, status: 204 }
  }
  assert.equal(await service.deleteOwnAccount(password), null)
})

test('confirmation and password are required, double clicks make one request and failures never emit deletion', async () => {
  store.auth.user = { id: 14, username: 'worker', email: 'worker@gotham.city', role: 'employee' }
  let requests = 0, finish
  globalThis.fetch = async () => { requests += 1; return new Promise(resolve => { finish = resolve }) }
  const instance = vm()
  instance.openDeletion()
  await instance.deleteAccount()
  assert.equal(requests, 0)
  instance.deletionConfirmed = true; instance.deletionPassword = password
  const pending = instance.deleteAccount()
  await instance.deleteAccount()
  assert.equal(requests, 1)
  finish({ ok: false, status: 422, json: async () => ({ errors: { current_password: ['invalid'] } }) })
  await pending
  assert.deepEqual(instance.events, [])
  assert.ok(instance.deletionError.includes('incorrect'))
  assert.equal(instance.deletionPassword, '')
  assert.equal(instance.deletionOpen, true)
  assert.ok(store.auth.user)
  instance.closeDeletion()
  assert.equal(instance.deletionConfirmed, false)
})

test('a successful response emits deletion once and clears password fields; malformed success is rejected', async () => {
  store.auth.user = { id: 14, username: 'worker', email: 'worker@gotham.city', role: 'employee' }
  const instance = vm(); instance.openDeletion(); instance.deletionConfirmed = true; instance.deletionPassword = password
  globalThis.fetch = async () => ({ ok: true, status: 204 })
  await instance.deleteAccount()
  assert.deepEqual(instance.events, ['deleted'])
  assert.equal(instance.deletionOpen, false)
  assert.equal(instance.deletionPassword, '')
  globalThis.fetch = async () => ({ ok: true, status: 200, json: async () => ({ data: { id: 14 } }) })
  await assert.rejects(service.deleteOwnAccount(password), /pas été confirmée/)
})


test('leaving the account page while deletion is pending cannot log out a different session', async () => {
  store.auth.user = { id: 14, username: 'worker', email: 'worker@gotham.city', role: 'employee' }
  let finish
  globalThis.fetch = async () => new Promise(resolve => { finish = resolve })
  const instance = vm(); instance.openDeletion(); instance.deletionConfirmed = true; instance.deletionPassword = password
  const pending = instance.deleteAccount()
  Profile.beforeUnmount.call(instance)
  store.auth.user = { id: 15, username: 'other', email: 'other@gotham.city', role: 'employee' }
  finish({ ok: true, status: 204 })
  await pending
  assert.deepEqual(instance.events, [])
  assert.equal(store.auth.user.id, 15)
  assert.equal(instance.deletionPassword, '')
})
