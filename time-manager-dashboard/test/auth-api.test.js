import assert from 'node:assert/strict'
import { after, before, test } from 'node:test'
import { createServer } from 'vite'

let server
let auth
const originalFetch = globalThis.fetch
const user = { id: 14, first_name: 'Sara', last_name: 'Martin', username: 'sara@example.com', email: 'sara@example.com', organization_id: 'org-123', role: 'employee' }
const session = { role: 'employee', user, organization: { id: 'org-123', name: 'Gotham' } }

before(async () => {
  server = await createServer({ configFile: false, server: { middlewareMode: true, hmr: false }, appType: 'custom', define: { 'import.meta.env.VITE_AUTH_USE_MOCK': JSON.stringify('false') } })
  auth = await server.ssrLoadModule('/src/services/organizationService.js')
  assert.equal(auth.AUTH_USE_MOCK, false)
})
after(async () => { globalThis.fetch = originalFetch; await server?.close() })

function expectRequest(path, method, body, result = session, status = 200) {
  globalThis.fetch = async (url, options) => {
    assert.equal(url, `/api${path}`)
    assert.equal(options.method, method)
    assert.equal(options.credentials, 'include')
    assert.equal(options.headers['Content-Type'], 'application/json')
    if (body === undefined) assert.equal(options.body, undefined)
    else assert.deepEqual(JSON.parse(options.body), body)
    return { ok: status < 400, status, json: async () => ({ data: result }) }
  }
}

test('real organization and session requests match the backend contract and include cookies', async () => {
  const creation = { name: 'Gotham', profile: { email: user.email }, password: 'Password2026!' }
  expectRequest('/organizations', 'POST', creation)
  assert.deepEqual(await auth.createOrganization(creation), session)
  const credentials = { email: user.email, password: 'Password2026!' }
  expectRequest('/auth/login', 'POST', credentials)
  assert.deepEqual(await auth.loginAccount(credentials), session)
  expectRequest('/auth/session', 'GET')
  assert.deepEqual(await auth.getSession(), session)
  expectRequest('/auth/logout', 'POST', undefined, null, 204)
  assert.equal(await auth.logoutAccount(), null)
})

test('lookup, join, receipt, review and role requests match exact paths and JSON bodies', async () => {
  expectRequest('/organizations/lookup?name=Gotham%20%26%20Co', 'GET', undefined, { id: 'org-123', name: 'Gotham & Co' })
  await auth.lookupOrganization('Gotham & Co')
  const join = { organization_id: 'org-123', profile: { email: user.email } }
  expectRequest('/join-requests', 'POST', join, { id: 'req-123', reference: 'private', status: 'pending' }, 201)
  await auth.joinOrganization(join)
  expectRequest('/join-requests/status', 'POST', { reference: 'private' }, { status: 'pending' })
  await auth.getRequestStatus('private')
  expectRequest('/organizations/org-123/join-requests', 'GET', undefined, [])
  await auth.listJoinRequests('org-123')
  expectRequest('/organizations/org-123/join-requests/req-123/approve', 'POST', { password: 'EmployeePassword!' }, { request: {}, user })
  await auth.approveJoinRequest('org-123', 'req-123', 'EmployeePassword!')
  expectRequest('/organizations/org-123/join-requests/req-123/reject', 'POST', { reason: 'Autre organisation' }, {})
  await auth.rejectJoinRequest('org-123', 'req-123', 'Autre organisation')
  expectRequest('/organizations/org-123/members', 'GET', undefined, [user])
  await auth.listMembers('org-123')
  expectRequest('/organizations/org-123/members/14', 'PATCH', { role: 'manager' }, { ...user, role: 'manager' })
  await auth.setMemberRole('org-123', 14, 'manager')
})

test('server errors retain their status and field details, malformed sessions are refused', async () => {
  globalThis.fetch = async () => ({ ok: false, status: 409, json: async () => ({ errors: { detail: 'Nom déjà utilisé', name: ['Nom déjà utilisé'] } }) })
  await assert.rejects(() => auth.createOrganization({}), (error) => error.status === 409 && error.message === 'Nom déjà utilisé' && error.payload.errors.name[0] === 'Nom déjà utilisé')
  expectRequest('/auth/session', 'GET', undefined, { ...session, role: 'admin' })
  await assert.rejects(() => auth.getSession(), /Réponse de session invalide/)
  globalThis.fetch = async () => ({ ok: true, status: 200, json: async () => ({ unexpected: [] }) })
  await assert.rejects(() => auth.listMembers('org-123'), /Réponse du serveur invalide/)
})
