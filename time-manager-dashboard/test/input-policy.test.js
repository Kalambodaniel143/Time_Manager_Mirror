import assert from 'node:assert/strict'
import { before, after, test } from 'node:test'
import { createServer } from 'vite'
import vue from '@vitejs/plugin-vue'

let server, registration, errors, locale, recovery, workforce, store, AdminTeams
const originalFetch = globalThis.fetch
before(async () => {
  server = await createServer({ configFile: false, plugins: [vue()], server: { middlewareMode: true, hmr: false }, appType: 'custom', define: { 'import.meta.env.VITE_AUTH_USE_MOCK': '"false"', 'import.meta.env.VITE_USE_MOCK': '"false"' } })
  registration = await server.ssrLoadModule('/src/utils/registration.js')
  errors = await server.ssrLoadModule('/src/utils/apiErrors.js')
  locale = await server.ssrLoadModule('/src/utils/i18n.js')
  recovery = await server.ssrLoadModule('/src/services/passwordRecoveryService.js')
  workforce = await server.ssrLoadModule('/src/services/workforceService.js')
  store = await server.ssrLoadModule('/src/stores/auth.js')
  AdminTeams = (await server.ssrLoadModule('/src/views/AdminTeams.vue')).default
})
after(async () => { globalThis.fetch = originalFetch; locale.setLocale('fr'); await server.close() })
test('adult cutoff uses calendar birthdays, including leap years', () => {
  assert.equal(registration.latestAdultBirthDate(new Date('2026-10-13T12:00:00Z')), '2008-10-13')
  assert.equal(registration.latestAdultBirthDate(new Date('2026-02-28T12:00:00Z')), '2008-02-29')
  assert.equal(registration.latestAdultBirthDate(new Date('2024-02-29T12:00:00Z')), '2006-02-28')
  const profile = {first_name:'Éléonore',last_name:'D’Angelo-Santos',email:'example@example.com',gender:'unspecified',birth_place:'Paris',birth_date:'2020-01-01'}
  assert.match(registration.profileErrors(profile).birth_date, /18 ans/)
  assert.equal(registration.profileErrors({...profile,birth_date:'1990-01-01'}).birth_date, undefined)
})
test('names support accents and compound names but reject ASCII and Unicode digits', () => {
  for (const name of ['Éléonore', 'D’Angelo-Santos', 'Jean Luc', '李明']) assert.equal(registration.nameError(name), '')
  for (const name of ['Jean2','A１２','Marie٣']) assert.match(registration.nameError(name), /sans chiffres/)
})
test('weak new passwords are rejected without imposing arbitrary character classes', () => {
  for (const password of ['123456789','987654321','Password2026!','azerty123','aaaaaaaa','abcdabcd']) assert.match(registration.passwordError(password), /facile/)
  assert.equal(registration.passwordError('une promenade sur la lune'), '')
  assert.equal(registration.passwordError('Lantern8'), '')
  assert.match(registration.passwordError('short'), /8 et 128/)
})
test('API errors explain field failures and preserve permission reasons without exposing server internals', () => {
  assert.match(errors.apiErrorMessage(422,{errors:{first_name:["can't be blank"],password:['should be at least 8 character(s)']}}), /Prénom : Ce champ est obligatoire.*Mot de passe : Saisissez au moins 8/)
  assert.match(errors.apiErrorMessage(403,{errors:{detail:'Seul le manager de cette équipe peut publier.'}}), /Seul le manager/)
  assert.doesNotMatch(errors.apiErrorMessage(500,{errors:{detail:'SQL private table'}}), /SQL/)
  assert.match(errors.apiErrorMessage(0,{}), /connexion internet/)
})
test('English translations preserve names and dynamic values and can be switched back', () => {
  locale.setLocale('en')
  assert.equal(locale.t('Mot de passe oublié'), 'Forgot password')
  assert.equal(locale.t('Nom de Équipe Nando'), 'Name of Équipe Nando')
  assert.equal(locale.t('Saisissez au moins 8 caractères.'), 'Enter at least 8 characters.')
  assert.equal(locale.t('Prénom : Ce champ est obligatoire.'), 'First name: This field is required.')
  assert.equal(locale.t('Un commentaire écrit par Nando'), 'Un commentaire écrit par Nando')
  assert.equal(locale.intlLocale(), 'en-GB')
  locale.setLocale('fr')
  assert.equal(locale.t('Mot de passe oublié'), 'Mot de passe oublié')
})
test('password recovery posts the expected payload and never fabricates a successful response', async () => {
  const calls = []
  globalThis.fetch = async (url, options) => { calls.push({url,body:JSON.parse(options.body)}); return {ok:true,status:200,json:async()=>({data:{message:'Reçu'}})} }
  await recovery.requestPasswordRecovery('example@example.com')
  await recovery.resetPassword('example@example.com','12345678','une promenade sur la lune')
  assert.deepEqual(calls, [
    {url:'/api/auth/forgot-password',body:{email:'example@example.com'}},
    {url:'/api/auth/reset-password',body:{email:'example@example.com',code:'12345678',password:'une promenade sur la lune'}},
  ])
  globalThis.fetch = async () => ({ok:true,status:200,json:async()=>({data:{}})})
  await assert.rejects(recovery.requestPasswordRecovery('example@example.com'), /pas confirmé/)
})
test('notification filters and badge count are requested from the authenticated API', async () => {
  store.auth.user = {id:7}; store.auth.organizationSession = null
  const urls = []
  globalThis.fetch = async url => { urls.push(url); return {ok:true,status:200,json:async()=>({data:url.includes('/count') ? {unread:63} : []})} }
  await workforce.listNotifications('unread',2)
  await workforce.refreshNotificationCount()
  assert.deepEqual(urls, ['/api/notifications?status=unread&page=2','/api/notifications/count'])
  assert.equal(workforce.workforce.unreadCount,63)
})
test('team member choices exclude the manager and existing members', () => {
  assert.deepEqual(AdminTeams.methods.candidates.call({users:[{id:1},{id:2},{id:3}]}, {manager:{id:1},members:[{id:2}]}), [{id:3}])
})
