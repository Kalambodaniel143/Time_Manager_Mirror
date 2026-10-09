import assert from 'node:assert/strict'
import { webcrypto } from 'node:crypto'
import { after, before, beforeEach, test } from 'node:test'
import { createServer } from 'vite'

let server, demo, service, LoginScreen
const storage = new Map()
const basic = { first_name: 'Nando', last_name: 'Martin', email: 'super@gotham.city' }
const applicant = { first_name: 'Sara', last_name: 'Ortiz', email: 'sara@gotham.city', gender: 'female', birth_date: '1999-03-12', birth_place: 'Paris' }
const password = 'Password8'
before(async () => {
  globalThis.localStorage = { getItem: key => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, String(value)), removeItem: key => storage.delete(key) }
  if (!globalThis.crypto) globalThis.crypto = webcrypto
  server = await createServer({ server: { middlewareMode: true, hmr: false }, appType: 'custom', define: { 'import.meta.env.VITE_AUTH_USE_MOCK': JSON.stringify('true') } })
  demo = await server.ssrLoadModule('/src/mocks/organizationAuth.js')
  service = await server.ssrLoadModule('/src/services/organizationService.js')
  LoginScreen = (await server.ssrLoadModule('/src/views/LoginScreen.vue')).default
})
beforeEach(() => storage.clear())
after(async () => { await server.close() })

test('manual provisioning creates the one super administrator without logging in or inventing a password', async () => {
  assert.throws(demo.mockSession, error => error.status === 401)
  const session = await demo.mockProvisionSuperAdministrator({ profile: basic, password })
  assert.equal(session.organization.name, 'Gotham City')
  assert.equal(session.role, 'admin')
  assert.throws(demo.mockSession, error => error.status === 401)
  await assert.rejects(demo.mockProvisionSuperAdministrator({ profile: basic, password }), error => error.status === 409)
  assert.equal((await service.loginAccount({ email: basic.email, password })).role, 'admin')
})

test('an application only contains profile data; Gotham is resolved automatically and no active account is created', async () => {
  const admin = await demo.mockProvisionSuperAdministrator({ profile: basic, password })
  const receipt = await service.joinOrganization({ profile: applicant, organization_id: 'forged-other-city' })
  assert.equal(receipt.status, 'pending')
  assert.equal(receipt.organization_name, 'Gotham City')
  assert.throws(demo.mockSession, error => error.status === 401)
  await assert.rejects(service.loginAccount({ email: applicant.email, password }), error => error.status === 401)
  await service.loginAccount({ email: basic.email, password })
  const requests = await service.listJoinRequests(admin.organization.id)
  assert.deepEqual(requests[0].profile, applicant)
  await service.approveJoinRequest(admin.organization.id, requests[0].id, password)
  const employee = await service.loginAccount({ email: applicant.email, password })
  assert.equal(employee.role, 'employee')
  assert.equal(employee.organization.id, admin.organization.id)
})

test('no public creation mode survives; direct /inscription opens the join form', () => {
  const vm = { ...LoginScreen.data.call({ initialMode: 'join' }), profile: {} }
  assert.equal(vm.mode, 'join')
  assert.deepEqual(vm.modes.map(item => item.value), ['login', 'join'])
  LoginScreen.methods.changeMode.call(vm, 'create')
  assert.equal(vm.mode, 'join')
  assert.equal('organizationName' in vm, false)
  assert.equal(service.createOrganization, undefined)
})

test('joining cannot auto-create Gotham or an administrator when manual provisioning has not happened', async () => {
  await assert.rejects(service.joinOrganization({ profile: applicant }), /pas encore configurée/)
  assert.throws(demo.mockSession, error => error.status === 401)
  await assert.rejects(service.loginAccount({ email: basic.email, password }), error => error.status === 401)
})
