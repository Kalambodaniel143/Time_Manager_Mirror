import assert from 'node:assert/strict'
import { after, before, test } from 'node:test'
import { createServer } from 'vite'

let server, auth
const originalFetch = globalThis.fetch
const user = { id: 14, first_name: 'Sara', last_name: 'Martin', username: 'sara@example.com', email: 'sara@example.com', organization_id: 'org-123', role: 'employee' }
const session = { role: 'employee', user, organization: { id: 'org-123', name: 'Gotham City' } }

before(async () => {
  server = await createServer({ configFile: false, server: { middlewareMode: true, hmr: false }, appType: 'custom', define: { 'import.meta.env.VITE_AUTH_USE_MOCK': JSON.stringify('false') } })
  auth = await server.ssrLoadModule('/src/services/organizationService.js')
})
after(async () => { globalThis.fetch = originalFetch; await server?.close() })

function expectRequest(path, method, body, result = session, status = 200) {
  globalThis.fetch = async (url, options) => {
    assert.equal(url, `/api${path}`)
    assert.equal(options.method, method)
    assert.equal(options.credentials, 'same-origin')
    assert.equal(options.headers['Content-Type'], 'application/json')
    if (body === undefined) assert.equal(options.body, undefined)
    else assert.deepEqual(JSON.parse(options.body), body)
    return { ok: status < 400, status, json: async () => ({ data: result }) }
  }
}

test('public organization creation is removed; login and session use the existing backend', async () => {
  assert.equal(auth.createOrganization, undefined)
  assert.equal(auth.lookupOrganization, undefined)
  const credentials = { email: user.email, password: 'Password8' }
  expectRequest('/auth/login', 'POST', credentials, { ...session, csrf_token: 'csrf-token' })
  assert.deepEqual(await auth.loginAccount(credentials), { ...session, csrf_token: 'csrf-token' })
  expectRequest('/auth/session', 'GET')
  assert.deepEqual(await auth.getSession(), session)
  expectRequest('/auth/logout', 'POST', undefined, null, 204)
  assert.equal(await auth.logoutAccount(), null)
})

test('joining always resolves Gotham City and ignores an organization ID supplied by the applicant', async () => {
  const calls = []
  const profile = { email: user.email }
  globalThis.fetch = async (url, options) => {
    calls.push(url)
    if (url === '/api/organizations/lookup?name=Gotham%20City') return { ok: true, status: 200, json: async () => ({ data: session.organization }) }
    assert.equal(url, '/api/join-requests')
    assert.deepEqual(JSON.parse(options.body), { organization_id: 'org-123', profile })
    return { ok: true, status: 201, json: async () => ({ data: { id: 'req-1', reference: 'private', status: 'pending' } }) }
  }
  await auth.joinOrganization({ organization_id: 'foreign-org', profile })
  assert.deepEqual(calls, ['/api/organizations/lookup?name=Gotham%20City', '/api/join-requests'])
})

test('receipt, review and role requests preserve the existing API paths and payloads', async () => {
  expectRequest('/join-requests/status', 'POST', { reference: 'private' }, { status: 'pending' }); await auth.getRequestStatus('private')
  expectRequest('/organizations/org-123/join-requests', 'GET', undefined, []); await auth.listJoinRequests('org-123')
  expectRequest('/organizations/org-123/join-requests/req-123/approve', 'POST', { password: 'Password8' }, { request: {}, user }); await auth.approveJoinRequest('org-123', 'req-123', 'Password8')
  expectRequest('/organizations/org-123/join-requests/req-123/reject', 'POST', { reason: 'Demande incorrecte' }, {}); await auth.rejectJoinRequest('org-123', 'req-123', 'Demande incorrecte')
  expectRequest('/organizations/org-123/members', 'GET', undefined, [user]); await auth.listMembers('org-123')
  expectRequest('/organizations/org-123/members/14', 'PATCH', { role: 'manager' }, { ...user, role: 'manager' }); await auth.setMemberRole('org-123', 14, 'manager')
})

test('administrator responses map to the super-administrator interface; other organizations are rejected', async () => {
  expectRequest('/auth/session', 'GET', undefined, { ...session, role: 'administrator', user: { ...user, role: 'administrator' } })
  assert.equal((await auth.getSession()).role, 'admin')
  expectRequest('/auth/session', 'GET', undefined, { ...session, organization: { id: 'org-123', name: 'Autre ville' } })
  await assert.rejects(auth.getSession(), /Gotham City/)
})

test('missing Gotham never submits an application; malformed sessions and API failures remain visible', async () => {
  globalThis.fetch = async url => { assert.equal(url, '/api/organizations/lookup?name=Gotham%20City'); return { ok: false, status: 404, json: async () => ({ errors: { detail: 'Not found' } }) } }
  await assert.rejects(auth.joinOrganization({ profile: {} }), /pas encore configurée/)
  expectRequest('/auth/login', 'POST', { email: user.email, password: 'Password8' }, session)
  await assert.rejects(auth.loginAccount({ email: user.email, password: 'Password8' }), /CSRF absent/)
  expectRequest('/auth/session', 'GET', undefined, { ...session, role: 'admin' })
  await assert.rejects(auth.getSession(), /Réponse de session invalide/)
  globalThis.fetch = async () => ({ ok: true, status: 200, json: async () => ({ unexpected: [] }) })
  await assert.rejects(auth.listMembers('org-123'), /Réponse du serveur invalide/)
})
