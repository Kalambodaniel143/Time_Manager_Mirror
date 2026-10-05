import assert from 'node:assert/strict'
import { webcrypto } from 'node:crypto'
import { beforeEach, test } from 'node:test'
import * as auth from '../src/mocks/organizationAuth.js'
import { profileErrors } from '../src/utils/registration.js'

const store = new Map()
globalThis.localStorage = { getItem: (key) => store.get(key) ?? null, setItem: (key, value) => store.set(key, String(value)), removeItem: (key) => store.delete(key) }
if (!globalThis.crypto) globalThis.crypto = webcrypto
const password = 'MotDePasseAdmin2026!'
const profile = (email = 'admin@example.com') => ({ first_name: 'Nando', last_name: 'Martin', email, gender: 'male', birth_date: '1999-03-12', birth_place: 'Paris' })
const create = (name = 'Atelier Gotham', email) => auth.mockCreateOrganization({ name, profile: profile(email), password })
const hasStatus = (status) => (error) => error.status === status
beforeEach(() => store.clear())

test('organization creation makes its creator admin, restores session, and stores no clear password', async () => {
  const session = await create()
  assert.equal(session.role, 'admin')
  assert.equal(session.user.organization_id, session.organization.id)
  assert.deepEqual(auth.mockSession(), session)
  assert.ok(!store.get('tm-auth-demo-v1').includes(password))
  assert.ok(!('password_hash' in session.user))
  for (const key of ['gender', 'birth_date', 'birth_place']) assert.ok(!(key in session.user))
  auth.mockLogout()
  assert.throws(() => auth.mockSession(), hasStatus(401))
  assert.deepEqual(await auth.mockLogin({ email: ' ADMIN@EXAMPLE.COM ', password }), session)
})

test('organization creation only requires name, surname and email; joining still requires personal details', async () => {
  const basicProfile = { first_name: 'Nando', last_name: 'Martin', email: 'admin@example.com' }
  assert.deepEqual(profileErrors(basicProfile, false), {})
  const session = await auth.mockCreateOrganization({ name: 'Atelier', profile: basicProfile, password })
  assert.equal(session.role, 'admin')
  const applicant = { ...basicProfile, email: 'employee@example.com' }
  assert.throws(() => auth.mockJoinOrganization({ organization_id: session.organization.id, profile: applicant }), hasStatus(422))
})

test('eight-character passwords work for administrators and employees; seven characters are rejected', async () => {
  const body = { name: 'Atelier', profile: profile() }
  await assert.rejects(() => auth.mockCreateOrganization({ ...body, password: '1234567' }), hasStatus(422))
  const admin = await auth.mockCreateOrganization({ ...body, password: '12345678' })
  const request = auth.mockJoinOrganization({ organization_id: admin.organization.id, profile: profile('employee@example.com') })
  await assert.rejects(() => auth.mockApproveRequest(admin.organization.id, request.id, '1234567'), hasStatus(422))
  await auth.mockApproveRequest(admin.organization.id, request.id, '87654321')
  auth.mockLogout()
  assert.equal((await auth.mockLogin({ email: 'employee@example.com', password: '87654321' })).role, 'employee')
  assert.equal((await auth.mockLogin({ email: admin.user.email, password: '12345678' })).role, 'admin')
})

test('invalid profile, impossible/future dates and short passwords cannot create an account', async () => {
  for (const birth_date of ['2030-01-01', '2000-02-30', '', '1899-01-01']) assert.ok(profileErrors({ ...profile(), birth_date }).birth_date)
  await assert.rejects(() => auth.mockCreateOrganization({ name: 'Gotham', profile: { ...profile(), email: 'bad' }, password }), hasStatus(422))
  await assert.rejects(() => auth.mockCreateOrganization({ name: 'Gotham', profile: profile(), password: 'short' }), hasStatus(422))
  assert.equal(store.has('tm-auth-demo-v1'), false)
})

test('organization names are normalized and duplicate emails are rejected', async () => {
  await create('Équipe   Gotham')
  assert.equal(auth.mockLookupOrganization(' equipe gotham ').name, 'Équipe Gotham')
  await assert.rejects(() => create('equipe gotham', 'other@example.com'), hasStatus(409))
  await assert.rejects(() => create('Autre équipe'), hasStatus(409))
  assert.throws(() => auth.mockLookupOrganization('Inconnue'), hasStatus(404))
})

test('a join request does not create a session; the administrator supplies the employee password', async () => {
  const admin = await create()
  auth.mockLogout()
  const receipt = auth.mockJoinOrganization({ organization_id: admin.organization.id, profile: profile('employee@example.com') })
  assert.equal(receipt.status, 'pending')
  assert.throws(() => auth.mockSession(), hasStatus(401))
  await assert.rejects(() => auth.mockLogin({ email: 'employee@example.com', password }), hasStatus(401))
  await auth.mockLogin({ email: 'admin@example.com', password })
  const result = await auth.mockApproveRequest(admin.organization.id, receipt.id, 'PasswordEmployee2026!')
  assert.equal(result.user.role, 'employee')
  assert.equal(auth.mockRequestStatus(receipt.reference).status, 'approved')
  assert.ok(!('reference' in auth.mockListRequests(admin.organization.id)[0]))
  assert.ok(!JSON.stringify(result).includes('PasswordEmployee2026!'))
  auth.mockLogout()
  const employee = await auth.mockLogin({ email: 'employee@example.com', password: 'PasswordEmployee2026!' })
  assert.equal(employee.role, 'employee')
  assert.equal(employee.organization.id, admin.organization.id)
})

test('duplicate pending requests and unknown organizations are rejected', async () => {
  const admin = await create()
  const body = { organization_id: admin.organization.id, profile: profile('employee@example.com') }
  auth.mockJoinOrganization(body)
  assert.throws(() => auth.mockJoinOrganization(body), hasStatus(409))
  assert.throws(() => auth.mockJoinOrganization({ ...body, organization_id: 'missing' }), hasStatus(404))
  assert.throws(() => auth.mockRequestStatus('missing'), hasStatus(404))
})

test('rejection provides a reason, creates no account and allows a new request', async () => {
  const admin = await create()
  const body = { organization_id: admin.organization.id, profile: profile('employee@example.com') }
  const receipt = auth.mockJoinOrganization(body)
  assert.throws(() => auth.mockRejectRequest(admin.organization.id, receipt.id, ''), hasStatus(422))
  auth.mockRejectRequest(admin.organization.id, receipt.id, 'Organisation incorrecte')
  assert.equal(auth.mockRequestStatus(receipt.reference).rejection_reason, 'Organisation incorrecte')
  await assert.rejects(() => auth.mockApproveRequest(admin.organization.id, receipt.id, password), hasStatus(409))
  assert.equal(auth.mockListMembers(admin.organization.id).length, 1)
  assert.notEqual(auth.mockJoinOrganization(body).id, receipt.id)
})

test('approval is atomic and cannot be replayed', async () => {
  const admin = await create()
  const receipt = auth.mockJoinOrganization({ organization_id: admin.organization.id, profile: profile('employee@example.com') })
  await assert.rejects(() => auth.mockApproveRequest(admin.organization.id, receipt.id, 'short'), hasStatus(422))
  assert.equal(auth.mockRequestStatus(receipt.reference).status, 'pending')
  assert.equal(auth.mockListMembers(admin.organization.id).length, 1)
  const attempts = await Promise.allSettled([auth.mockApproveRequest(admin.organization.id, receipt.id, password), auth.mockApproveRequest(admin.organization.id, receipt.id, password)])
  assert.equal(attempts.filter((result) => result.status === 'fulfilled').length, 1)
  assert.equal(auth.mockListMembers(admin.organization.id).length, 2)
})

test('an administrator can neither review another organization nor change its members', async () => {
  const first = await create('Première')
  const request = auth.mockJoinOrganization({ organization_id: first.organization.id, profile: profile('employee@example.com') })
  const second = await create('Deuxième', 'second@example.com')
  assert.throws(() => auth.mockListRequests(first.organization.id), hasStatus(403))
  assert.throws(() => auth.mockListMembers(first.organization.id), hasStatus(403))
  await assert.rejects(() => auth.mockApproveRequest(first.organization.id, request.id, password), hasStatus(403))
  assert.throws(() => auth.mockRejectRequest(first.organization.id, request.id, 'Non'), hasStatus(403))
  assert.throws(() => auth.mockSetRole(first.organization.id, first.user.id, 'manager'), hasStatus(403))
  await assert.rejects(() => auth.mockApproveRequest(second.organization.id, request.id, password), hasStatus(404))
})

test('employees cannot promote themselves, administrators can promote and demote, refreshed sessions reflect roles', async () => {
  const admin = await create()
  const receipt = auth.mockJoinOrganization({ organization_id: admin.organization.id, profile: profile('employee@example.com') })
  const { user } = await auth.mockApproveRequest(admin.organization.id, receipt.id, password)
  auth.mockLogout()
  await auth.mockLogin({ email: user.email, password })
  assert.throws(() => auth.mockListRequests(admin.organization.id), hasStatus(403))
  assert.throws(() => auth.mockSetRole(admin.organization.id, user.id, 'manager'), hasStatus(403))
  await auth.mockLogin({ email: admin.user.email, password })
  assert.throws(() => auth.mockSetRole(admin.organization.id, user.id, 'admin'), hasStatus(403))
  assert.throws(() => auth.mockSetRole(admin.organization.id, admin.user.id, 'employee'), hasStatus(403))
  auth.mockSetRole(admin.organization.id, user.id, 'manager')
  await auth.mockLogin({ email: user.email, password })
  assert.equal(auth.mockSession().role, 'manager')
  await auth.mockLogin({ email: admin.user.email, password })
  auth.mockSetRole(admin.organization.id, user.id, 'employee')
  assert.equal((await auth.mockLogin({ email: user.email, password })).role, 'employee')
})
