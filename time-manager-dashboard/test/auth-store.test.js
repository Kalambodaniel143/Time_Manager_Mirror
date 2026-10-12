import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createServer } from 'vite'

function memoryStorage() {
  const values = new Map()
  return { getItem: (key) => values.get(key) ?? null, setItem: (key, value) => values.set(key, String(value)), removeItem: (key) => values.delete(key) }
}

async function withStore(mock, run) {
  const previous = { localStorage: globalThis.localStorage, sessionStorage: globalThis.sessionStorage, fetch: globalThis.fetch }
  globalThis.localStorage = memoryStorage()
  globalThis.sessionStorage = memoryStorage()
  const server = await createServer({ configFile: false, server: { middlewareMode: true, hmr: false }, appType: 'custom', define: { 'import.meta.env.VITE_AUTH_USE_MOCK': JSON.stringify(String(mock)), 'import.meta.env.VITE_USE_MOCK': JSON.stringify('false') } })
  try { await run(await server.ssrLoadModule('/src/stores/auth.js'), server) }
  finally { await server.close(); Object.assign(globalThis, previous) }
}

test('organization sessions restore through the shared store with compatible roles and local logout', async () => {
  await withStore(true, async (store, server) => {
    globalThis.fetch = () => { throw new Error('The organization demo must not call the backend') }
    const service = await server.ssrLoadModule('/src/services/organizationService.js')
    const demo = await server.ssrLoadModule('/src/mocks/organizationAuth.js')
    await demo.mockProvisionSuperAdministrator({ profile: { first_name: 'Nando', last_name: 'Martin', email: 'admin@example.com' }, password: 'Password8' })
    const session = await service.loginAccount({ email: 'admin@example.com', password: 'Password8' })
    store.startOrganizationSession(session)
    assert.equal(store.auth.user.role, 'administrator')
    assert.equal(store.auth.organizationSession.role, 'admin')
    assert.equal(store.hasRole('administrator'), true)
    assert.equal(store.canEditHours(99), true)
    assert.equal(store.auth.csrfToken, null)
    store.clearSession()
    await store.fetchMe()
    assert.equal(store.auth.user.id, session.user.id)
    assert.equal(store.auth.organizationSession.organization.name, 'Gotham City')
    await store.logout()
    assert.equal(store.auth.user, null)
    assert.equal(store.auth.organizationSession, null)
    await assert.rejects(service.getSession(), (error) => error.status === 401)
  })
})

test('backend login, restoration and logout retain the existing CSRF transport and role checks', async () => {
  await withStore(false, async (store, server) => {
    const { configureHttp } = await server.ssrLoadModule('/src/services/http.js')
    configureHttp({ csrfToken: () => store.auth.csrfToken })
    const user = { id: 14, username: 'Sara', email: 'sara@example.com', role: 'employee', first_name: 'Sara', last_name: 'Martin', organization_id: 'gotham-id' }
    const organization = { id: 'gotham-id', name: 'Gotham City' }
    const calls = []
    globalThis.fetch = async (url, options) => {
      calls.push({ url, ...options })
      const data = url.endsWith('/auth/login') ? { user, role: 'employee', organization, csrf_token: 'test-csrf' } : url.endsWith('/auth/session') ? { user, role: 'employee', organization } : null
      return { status: 200, ok: true, json: async () => ({ data }) }
    }
    await store.login(user.email, 'Password8')
    assert.equal(store.auth.csrfToken, 'test-csrf')
    assert.equal(globalThis.sessionStorage.getItem('tm-csrf'), 'test-csrf')
    assert.equal(store.auth.organizationSession, null)
    assert.equal(store.auth.organization.name, 'Gotham City')
    const clocks = await server.ssrLoadModule('/src/services/clockService.js')
    await clocks.getClocks(user.id)
    assert.equal(calls.at(-1).url, '/api/clocks/14')
    assert.equal(calls.at(-1).headers['X-CSRF-Token'], 'test-csrf')
    assert.equal(store.canEditHours(user.id), false)
    assert.equal(store.isSelf(user.id), true)
    await store.fetchMe()
    assert.deepEqual(store.auth.user, user)
    await store.logout()
    assert.deepEqual(calls.map((call) => call.url), ['/api/auth/login', '/api/clocks/14', '/api/auth/session', '/api/auth/logout'])
    assert.equal(calls[1].headers['X-CSRF-Token'], 'test-csrf')
    assert.equal(calls[3].headers['X-CSRF-Token'], 'test-csrf')
    assert.equal(calls[3].credentials, 'same-origin')
    assert.equal(store.auth.user, null)
    assert.equal(globalThis.sessionStorage.getItem('tm-csrf'), null)
  })
})
