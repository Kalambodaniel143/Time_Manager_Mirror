import assert from 'node:assert/strict'
import { before, after, beforeEach, test } from 'node:test'
import { createServer } from 'vite'
import vue from '@vitejs/plugin-vue'
let server, api, store, WorkingTime, ManagerNote, NextShifts, voice
const originalFetch = globalThis.fetch
const originalWindow = globalThis.window
const response = data => ({ ok: true, status: 200, json: async () => ({ data }) })
const context = { rules: { maxConsecutiveNights: 3, overtimeThreshold: 40, nightMultiplier: 1.5, overtimeMultiplier: 2 }, preferences: { theme: 'night', speech_enabled: true }, permissions: [{ team_id: 10, manager_id: 99, member_ids: [7,8], correct: true, validate: false, publish: true }] }
before(async () => {
  server = await createServer({ configFile: false, plugins: [vue()], server: { middlewareMode: true, hmr: false }, appType: 'custom', define: { 'import.meta.env.VITE_AUTH_USE_MOCK': JSON.stringify('false'), 'import.meta.env.VITE_USE_MOCK': JSON.stringify('false') } })
  store = await server.ssrLoadModule('/src/stores/auth.js')
  api = await server.ssrLoadModule('/src/services/workforceService.js')
  const http = await server.ssrLoadModule('/src/services/http.js')
  http.configureHttp({ csrfToken: () => store.auth.csrfToken })
  WorkingTime = (await server.ssrLoadModule('/src/components/WorkingTime.vue')).default
  ManagerNote = (await server.ssrLoadModule('/src/components/hours/ManagerNote.vue')).default
  NextShifts = (await server.ssrLoadModule('/src/components/employee/NextShifts.vue')).default
  voice = await server.ssrLoadModule('/src/utils/speech.js')
})
beforeEach(() => { api.clearWorkforce(); store.auth.user = {id:99,role:'manager',username:'manager'}; store.auth.csrfToken = 'workflow-csrf'; globalThis.fetch = async () => { throw new Error('Unexpected request') } })
after(async () => { globalThis.fetch = originalFetch; globalThis.window = originalWindow; await server.close() })
function vm(component, props = {}) {
  const instance = { ...props, ...component.data.call(props), events: [], $emit(name, value) { this.events.push({ name, value }) } }
  for (const [name, getter] of Object.entries(component.computed || {})) Object.defineProperty(instance, name, { get: () => getter.call(instance) })
  for (const [name, method] of Object.entries(component.methods)) instance[name] = method.bind(instance)
  return instance
}
function capture(result = {}) {
  const calls = []
  globalThis.fetch = async (url, options) => { calls.push({url,options}); assert.equal(options.headers['X-CSRF-Token'],'workflow-csrf'); assert.equal(options.credentials,'same-origin'); return response(result) }
  return calls
}
test('effective permissions require current role and assigned team membership', async () => {
  capture(context); await api.loadContext()
  assert.equal(api.canReviewTarget(7,'correct'),true)
  assert.equal(api.canReviewTarget(7,'validate'),false)
  assert.equal(api.canReviewTarget(30,'correct'),false)
  assert.equal(api.canReviewTarget(99,'correct'),false)
  store.auth.user.role = 'employee'; assert.equal(api.canReviewTarget(7,'correct'),false)
})
test('all writes use authenticated transport, scoped paths and exact payloads', async () => {
  const calls = capture({id:1})
  await api.saveRules('org', {publishDaysAhead:0})
  await api.savePermissions(10,{publish:true})
  await api.saveNote(7,'2026-10-05','Intervention')
  await api.validateSheets('2026-10-05',[7,8])
  await api.transitionSheet(7,'2026-10-05','reopen','Régularisation')
  await api.createPlan(10,{start:'2026-10-27',days:14})
  await api.saveShift(20,null,{user_id:7,revision:1,kind:'night'})
  await api.publishPlan(20,2)
  await api.requestSwap(3,4,'Famille')
  await api.consentSwap(5,true)
  await api.reviewSwap(5,'approved','Vérifié')
  await api.requestAbsence({start:'2026-11-01T08:00:00Z',end:'2026-11-01T16:00:00Z',kind:'leave'})
  await api.reviewAbsence(6,'approved','',8)
  await api.setAbsencePayment(6,8)
  await api.cancelAbsence(6,'Déplacement')
  await api.savePayProfile(7,{hourly_rate:'15.50',currency:'EUR'})
  await api.savePreferences({theme:'night',speech_enabled:true})
  await api.readNotification(9)
  assert.equal(calls.length,18)
  assert.equal(calls[0].url,'/api/organizations/org/rules')
  assert.deepEqual(JSON.parse(calls[3].options.body),{week:'2026-10-05',user_ids:[7,8]})
  assert.deepEqual(JSON.parse(calls[6].options.body),{shift:{user_id:7,revision:1,kind:'night'}})
  assert.deepEqual(JSON.parse(calls[12].options.body),{status:'approved',reason:'',payable_hours:8})
  assert.equal(calls[16].url,'/api/auth/preferences')
})
test('an expired context cannot contaminate a different logged-in account', async () => {
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve })
  const pending = api.loadContext()
  api.clearWorkforce(); store.auth.user = {id:8,role:'employee',username:'other'}
  finish(response(context)); await pending
  assert.equal(api.workforce.ready,false); assert.deepEqual(api.workforce.preferences,{})
})
test('malformed successful responses and API failures never become empty reports or local successes', async () => {
  capture(null); await assert.rejects(api.listPlans(),/invalide/)
  capture({bad:true}); await assert.rejects(api.listAbsences(),/invalide/)
  capture({rows:[]}); await assert.rejects(api.getPayroll('2026-09'),/invalide/)
  globalThis.fetch = async () => ({ok:false,status:409,json:async()=>({errors:{detail:'Version changed'}})})
  await assert.rejects(api.publishPlan(20,2),error=>error.status===409)
})
test('CSV export uses CSRF and reads text rather than JSON', async () => {
  globalThis.fetch = async (url,options) => { assert.equal(url,'/api/payroll/export?month=2026-09'); assert.equal(options.headers['X-CSRF-Token'],'workflow-csrf'); return {ok:true,status:200,text:async()=> 'Agent;Jour\nSara;8'} }
  assert.equal(await api.exportPayroll('2026-09'),'Agent;Jour\nSara;8')
})
test('working period forms preserve and send the actual compensation category', async () => {
  const calls = capture({id:3,start:'2026-09-28 08:00:00',end:'2026-09-28 16:00:00',kind:'recup'})
  const instance = vm(WorkingTime,{userId:7})
  instance.reset({id:3,start:'2026-09-28 08:00:00',end:'2026-09-28 16:00:00',kind:'oncall'})
  assert.equal(instance.form.kind,'oncall')
  instance.form.kind = 'recup'
  await instance.updateWorkingTime()
  assert.equal(JSON.parse(calls[0].options.body).workingtime.kind,'recup')
  assert.equal(instance.events[0].name,'saved')
})
test('notes use the signed-in author and show locked weeks without local saving', async () => {
  store.auth.user = {id:7,role:'employee',username:'worker'}
  const calls = capture({user_id:7,status:'closed',note:'Note déjà partagée'})
  const instance = vm(ManagerNote,{userId:7,username:'worker',weekKey:'2026-10-05'})
  await instance.load()
  assert.equal(calls[0].url,'/api/users/7/week-notes/2026-10-05')
  assert.equal(instance.weekStatus,'closed')
  assert.equal(instance.text,'Note déjà partagée')
})
test('next guards come from published snapshots and exclude other agents and past dates', async () => {
  store.auth.user = {id:7,role:'employee',username:'worker'}
  capture([{published_at:'2026-10-10T08:00:00Z',shifts:[{id:1,user_id:7,start:'2026-10-27T22:00:00Z',end:'2026-10-28T06:00:00Z',kind:'night',place:'Centre'},{id:2,user_id:8,start:'2026-10-28T22:00:00Z',end:'2026-10-29T06:00:00Z',kind:'night',place:'Autre'},{id:3,user_id:7,start:'2026-09-28T08:00:00Z',end:'2026-09-28T16:00:00Z',kind:'day',place:''}]}])
  const instance = vm(NextShifts,{today:new Date('2026-10-12T08:00:00Z')})
  await instance.load(); assert.equal(instance.shifts.length,1); assert.equal(instance.shifts[0].shift.hours,8); assert.equal(instance.shifts[0].place,'Centre')
})
test('week tables clip midnight boundaries without losing the underlying period identity', async () => {
  const hours = await server.ssrLoadModule('/src/utils/hours.js')
  const monday = new Date(2026,8,28)
  const entry = {id:6,start:'2026-09-27 22:00:00',end:'2026-09-28 06:00:00',kind:'work'}
  const clipped = hours.clipEntries([entry],monday,new Date(2026,9,5))
  assert.equal(clipped[0].id,6)
  assert.equal(clipped[0].start,'2026-09-28 00:00:00')
  assert.equal(hours.weekBuckets(clipped,40).total,6)
  assert.equal(hours.entriesByDay([entry],monday)[0].length,1)
  assert.equal(entry.start,'2026-09-27 22:00:00')
})

test('voice controls use device voices, previews and cancellation without stale callbacks', () => {
  const utterances = [], engine = { cancel() {}, getVoices: () => [{name:'Française',lang:'fr-FR'}], speak(item) {utterances.push(item)} }
  globalThis.window = {speechSynthesis:engine,SpeechSynthesisUtterance:class {constructor(text){this.text=text}}}
  voice.readAloud('Guide',{speech_rate:0.8,speech_voice:'Française'})
  assert.equal(utterances[0].rate,0.8); assert.equal(utterances[0].voice.name,'Française')
  utterances[0].onstart(); assert.equal(voice.speech.speaking,true)
  voice.readAloud('Nouvelle page'); utterances[1].onstart(); utterances[0].onend()
  assert.equal(voice.speech.speaking,true)
  voice.stopReading(); assert.equal(voice.speech.speaking,false)
})
