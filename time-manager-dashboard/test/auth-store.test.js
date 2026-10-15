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
    await demo.mockProvisionSuperAdministrator({ profile: { first_name: 'Nando', last_name: 'Martin', email: 'admin@example.com' }, password: 'Lantern8' })
    const session = await service.loginAccount({ email: 'admin@example.com', password: 'Lantern8' })
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
      const data = url.endsWith('/auth/login') ? { user, role: 'employee', organization, csrf_token: 'test-csrf' } : url.endsWith('/auth/session') ? { user, role: 'employee', organization, csrf_token: 'test-csrf' } : null
      return { status: 200, ok: true, json: async () => ({ data }) }
    }
    await store.login(user.email, 'Lantern8')
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

const realUser = { id: 14, username: 'Sara', email: 'sara@example.test', role: 'employee', first_name: 'Sara', last_name: 'Martin', organization_id: null }
const sessionFor = (csrf_token, user = realUser) => ({user, role:user.role, organization:null, csrf_token})
const jsonReply = (data, status = 200) => ({status,ok:status<400,json:async()=>status===401 ? {errors:{detail:'Unauthorized'}} : {data}})
function recoveryTransport(store, http) {
  http.configureHttp({csrfToken:()=>store.auth.csrfToken,currentUser:()=>store.auth.user?.id,restoreSession:store.restoreForRequest,onUnauthorized:store.clearSession})
}

test('a fresh tab with empty sessionStorage restores its session and CSRF from the cookie-backed API', async () => {
  await withStore(false, async (store, server) => {
    const http = await server.ssrLoadModule('/src/services/http.js'); recoveryTransport(store,http)
    globalThis.fetch = async (url, options) => {
      assert.equal(url,'/api/auth/session')
      assert.equal(options.headers['X-Session-Restore'],'1')
      assert.equal(options.headers['X-CSRF-Token'],undefined)
      assert.equal(options.credentials,'same-origin')
      return jsonReply(sessionFor('cookie-csrf'))
    }
    assert.equal((await store.fetchMe()).id,14)
    assert.equal(store.auth.csrfToken,'cookie-csrf')
    assert.equal(globalThis.sessionStorage.getItem('tm-csrf'),'cookie-csrf')
  })
})

test('concurrent same-account requests restore once and retry with the current CSRF without logging out', async () => {
  await withStore(false, async (store, server) => {
    const http = await server.ssrLoadModule('/src/services/http.js'); recoveryTransport(store,http)
    store.startOrganizationSession(sessionFor('old-csrf'))
    let reads=0, writes=0, completed=0
    globalThis.fetch = async (url, options) => {
      if (url==='/api/auth/session') { reads++; return jsonReply(sessionFor('current-csrf')) }
      writes++
      if (options.headers['X-CSRF-Token'] !== 'current-csrf') return jsonReply(null,401)
      completed++; return jsonReply({saved:true})
    }
    const result=await Promise.all([http.request('/one',{method:'POST',body:'{}'}),http.request('/two',{method:'POST',body:'{}'})])
    assert.deepEqual(result,[{saved:true},{saved:true}]);assert.equal(reads,1);assert.equal(writes,4);assert.equal(completed,2)
    assert.equal(store.auth.user.id,14)
  })
})

test('an action is never retried under another account after the shared cookie changes', async () => {
  await withStore(false, async (store,server)=>{
    const http=await server.ssrLoadModule('/src/services/http.js');recoveryTransport(store,http)
    store.startOrganizationSession(sessionFor('first-csrf'))
    let writes=0
    globalThis.fetch=async url=>{
      if(url==='/api/auth/session')return jsonReply(sessionFor('second-csrf',{...realUser,id:15,email:'other@example.test'}))
      writes++;return jsonReply(null,401)
    }
    await assert.rejects(http.request('/sensitive',{method:'PUT',body:'{}'}),error=>error.status===409 && /autre onglet/.test(error.message))
    assert.equal(writes,1);assert.equal(store.auth.user.id,15)
  })
})

test('revoked sessions clear the tab without retrying a protected action',async()=>{
  await withStore(false,async(store,server)=>{
    const http=await server.ssrLoadModule('/src/services/http.js');recoveryTransport(store,http)
    store.startOrganizationSession(sessionFor('old-csrf'));let calls=0
    globalThis.fetch=async()=>{calls++;return jsonReply(null,401)}
    await assert.rejects(http.request('/write',{method:'POST',body:'{}'}),error=>error.status===401)
    assert.equal(calls,2);assert.equal(store.auth.user,null);assert.equal(store.auth.csrfToken,null)
  })
})

test('a delayed session response cannot reopen a locally signed-out account',async()=>{
  await withStore(false,async(store)=>{
    let finish
    globalThis.fetch=()=>new Promise(resolve=>{finish=resolve})
    const pending=store.fetchMe();store.clearSession();finish(jsonReply(sessionFor('stale-csrf')))
    assert.equal(await pending,null);assert.equal(store.auth.user,null);assert.equal(store.auth.csrfToken,null)
  })
})

test('the login callback announces a refresh without sharing secrets, and receiving signals does not loop',async()=>{
  await withStore(false,async(store,server)=>{
    const previousWindow=globalThis.window, messages=[], persistent=new Map(), callbacks=new Map()
    let receiver, refreshed=0
    globalThis.window={
      localStorage:{setItem:(key,value)=>persistent.set(key,value)},
      addEventListener:(name,fn)=>callbacks.set(name,fn),removeEventListener:name=>callbacks.delete(name),
      BroadcastChannel:class{constructor(){receiver=this}postMessage(message){messages.push(message)}close(){}},
    }
    const events=await server.ssrLoadModule('/src/utils/sessionEvents.js')
    const stop=events.listenForSessionChanges(()=>refreshed++)
    try{
      store.startOrganizationSession(sessionFor('secret-csrf'))
      assert.equal(messages.length,1)
      assert.doesNotMatch(JSON.stringify([...persistent,...messages]),/secret-csrf|sara@example/)
      receiver.onmessage({data:{type:'refresh',id:'same-event'}})
      callbacks.get('storage')({key:'tm-session-event',newValue:'same-event'})
      assert.equal(refreshed,1)
      globalThis.fetch=async()=>jsonReply(sessionFor('restored-secret'))
      await store.fetchMe()
      assert.equal(messages.length,1)
    }finally{stop();globalThis.window=previousWindow}
  })
})
