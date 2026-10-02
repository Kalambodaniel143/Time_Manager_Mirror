import { CLOCK_USE_MOCK } from '../config'
import { mocked, request } from './http'
import { mockCreateClock, mockListClocks } from '../mocks/clocks'

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
