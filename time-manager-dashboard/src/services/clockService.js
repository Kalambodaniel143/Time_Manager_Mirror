import { CLOCK_USE_MOCK } from '../config'
import { mocked, request } from './http'
import { mockCreateClock, mockListClocks } from '../mocks/clocks'
import { departureError, localDateInput, clockDate } from '../utils/missingDeparture'

export function getClocks(userId) {
  if (CLOCK_USE_MOCK) {
    return mocked(() => mockListClocks(Number(userId)))
  }

  return request(`/clocks/${userId}`)
}

export function createClock(userId, attrs) {
  if (CLOCK_USE_MOCK) {
    return mocked(() => mockCreateClock(Number(userId), attrs))
  }

  return request(`/clocks/${userId}`, {
    method: 'POST',
    body: JSON.stringify({
      clock: attrs,
    }),
  })
}

export function completeDeparture(userId, clockId, time) {
  if (CLOCK_USE_MOCK) {
    return mocked(null).then(() => {
      const last = mockListClocks(Number(userId)).at(-1)
      if (!last || last.id !== clockId || (last.kind || (last.status ? 'arrival' : 'departure')) === 'departure') throw new Error('Pointages modifiés')
      const error = departureError(localDateInput(clockDate(time)), last, new Date())
      if (error) throw new Error(error)
      return mockCreateClock(Number(userId), { time, status: false, kind: 'departure' })
    })
  }
  return request(`/clocks/${userId}/${clockId}/complete`, {
    method: 'POST',
    body: JSON.stringify({ clock: { time } }),
  })
}
