// Share only a refresh signal. JWTs, CSRF tokens and user data never enter
// BroadcastChannel or localStorage; each tab restores them from the API.
const EVENT_KEY = 'tm-session-event'
let channel = null
export function announceSessionChange() {
  if (typeof window === 'undefined') return
  const signal = `${Date.now()}-${Math.random()}`
  channel?.postMessage({ type: 'refresh', id: signal })
  try { window.localStorage.setItem(EVENT_KEY, signal) } catch { /* Focus restoration remains available. */ }
}
export function listenForSessionChanges(refresh) {
  if (typeof window === 'undefined') return () => {}
  let lastSignal = null
  const receive = signal => {
    if (typeof signal !== 'string' || signal === lastSignal) return
    lastSignal = signal
    refresh()
  }
  const onStorage = event => { if (event.key === EVENT_KEY && event.newValue) receive(event.newValue) }
  if (typeof window.BroadcastChannel === 'function') {
    channel = new window.BroadcastChannel('tm-session')
    channel.onmessage = event => { if (event.data?.type === 'refresh') receive(event.data.id) }
  }
  window.addEventListener('storage', onStorage)
  return () => { window.removeEventListener('storage', onStorage); channel?.close(); channel = null }
}
