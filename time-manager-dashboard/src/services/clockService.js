import { auth } from '../stores/auth'
import { workClocks, workClock } from '../mocks/organizationWork'
import { request } from './http'
import { departureError, localDateInput, clockDate } from '../utils/missingDeparture'

export function getClocks(userId) {
  if (auth.organizationSession) return Promise.resolve().then(() => workClocks(userId))
  return request(`/clocks/${userId}`)
}

export function createClock(userId, attrs) {
  if (auth.organizationSession) return Promise.resolve().then(() => workClock(userId, attrs))
  return request(`/clocks/${userId}`, {
    method: 'POST',
    body: JSON.stringify({ clock: attrs }),
  })
}

export function completeDeparture(userId, clockId, time) {
  if (auth.organizationSession) return Promise.resolve().then(() => {
    const last = workClocks(userId).at(-1)
    if (!last) throw new Error('Pointages introuvables.')
    const error = departureError(localDateInput(clockDate(time)), last, new Date())
    if (error) throw new Error(error)
    return workClock(userId, { time, status: false, kind: 'departure' }, clockId)
  })
  return request(`/clocks/${userId}/${clockId}/complete`, {
    method: 'POST',
    body: JSON.stringify({ clock: { time } }),
  })
}
