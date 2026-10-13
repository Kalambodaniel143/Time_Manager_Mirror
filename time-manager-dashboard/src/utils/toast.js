import { reactive } from 'vue'

export const toasts = reactive([])

let seed = 0

export function dismiss(id) {
  const index = toasts.findIndex((toast) => toast.id === id)
  if (index !== -1) toasts.splice(index, 1)
}

export function notify(message, tone = 'success', timeout = tone === 'error' ? 0 : 5000) {
  seed += 1
  const id = seed

  toasts.push({ id, message, tone })
  if (timeout > 0) setTimeout(() => dismiss(id), timeout)

  return id
}
