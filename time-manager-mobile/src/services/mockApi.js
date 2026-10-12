import { read, write } from '@/storage/database.js'
import { getMockSettings, networkError, server, setMockSetting } from './mock/server.js'
import { mockOrgApi } from './mockOrgApi.js'
import { NEXT_KINDS } from '@/ui/clockState.js'
import { allow, canEditHours, canView, db, fail, findUser, passwordOf, publicUser, sessionOf } from './mock/db.js'
import { addPeriod, applyEdits, changePeriod, ownerOf, removePeriod } from './mock/hoursEdits.js'
import { mockUsersApi } from './mockUsersApi.js'
import { pastClocks, planning, workingTimes } from './mock/hours.js'
import { mockAdminApi } from './mockAdminApi.js'

// Faux serveur : même interface que api.js, mêmes règles d'accès que le backend.
// Pointages = historique fictif + pointages faits dans l'application.
const savedClocks = (userId) => read(`mock:clocks:${userId}`, [])
const clocksOf = (userId) => [...pastClocks(Number(userId)), ...savedClocks(userId)]

function createClock(me, userId, { kind, time }) {
  allow(me.id === Number(userId)) // chacun ne pointe que pour soi
  const clocks = clocksOf(userId)
  const last = clocks.at(-1)
  if (!NEXT_KINDS[last?.kind ?? 'none'].includes(kind) || (last && time < last.time)) {
    throw fail(422, 'action is not allowed after the latest clock event')
  }
  const clock = { id: savedClocks(userId).length + 1, kind, time, status: kind === 'arrival' || kind === 'resume', user_id: me.id }
  write(`mock:clocks:${userId}`, [...savedClocks(userId), clock])
  if (getMockSettings().loseNextResponse) { // test 7 : enregistré, mais réponse perdue
    setMockSetting('loseNextResponse', false)
    throw networkError()
  }
  return clock
}

// Départ oublié (POST /clocks/:id/:clockID/complete) : clockID doit être le dernier pointage.
function completeClock(me, userId, clockId, time) {
  const last = clocksOf(userId).at(-1)
  if (!last || last.id !== Number(clockId) || last.kind === 'departure') {
    throw fail(422, 'Les pointages ont changé. Actualisez avant de réessayer.')
  }
  if (new Date(time) > new Date()) throw fail(422, 'Le départ ne peut pas être dans le futur.')
  return createClock(me, userId, { kind: 'departure', time })
}

export const mockApi = {
  login: (email, password) => server(() => {
    const found = db().users.find((u) => u.email === email.trim().toLowerCase())
    if (!found || found.unverified || password !== passwordOf(found)) throw fail(401, 'Invalid credentials')
    setMockSetting('sessionExpired', false)
    return { csrf_token: 'mock-token', ...sessionOf(found) }
  }, { isLogin: true }),
  me: () => server((me) => publicUser(me)),
  getSession: () => server((me) => sessionOf(me)),
  logout: () => server(() => null),
  getUser: (id) => server((me) => { allow(canView(me, id)); return publicUser(findUser(id)) }),
  getClocks: (id) => server((me) => { allow(canView(me, id)); return clocksOf(id) }),
  createClock: (id, action) => server((me) => createClock(me, id, action)),
  completeClock: (id, clockId, time) => server((me) => completeClock(me, id, clockId, time)),
  getPlanning: (id) => server((me) => { allow(canView(me, id)); return planning(Number(id)) }),

  // Temps de travail : lecture (soi, son responsable, l'administration) et corrections.
  getWorkingTimes: (id) => server((me) => { allow(canView(me, id)); return applyEdits(id, workingTimes(Number(id), clocksOf(id))) }),
  getWorkingTime: (id, wtId) => server((me) => { allow(canView(me, id)); return applyEdits(id, workingTimes(Number(id), clocksOf(id))).find((p) => p.id === Number(wtId)) }),
  createWorkingTime: (id, period) => server((me) => { allow(canEditHours(me, id)); return addPeriod(id, period) }),
  updateWorkingTime: (wtId, period) => server((me) => { allow(canEditHours(me, ownerOf(wtId))); return changePeriod(ownerOf(wtId), wtId, period) }),
  deleteWorkingTime: (wtId) => server((me) => { allow(canEditHours(me, ownerOf(wtId))); removePeriod(ownerOf(wtId), wtId); return null }),

  ...mockUsersApi,
  ...mockAdminApi,
  ...mockOrgApi,
}
