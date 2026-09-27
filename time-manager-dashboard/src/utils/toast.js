import { reactive } from 'vue'

export const toasts = reactive([])

let seed = 0

export function dismiss(id) {
  const index = toasts.findIndex((toast) => toast.id === id)
  if (index !== -1) toasts.splice(index, 1)
}

export function notify(message, tone = 'success', timeout = 3400) {
  seed += 1
  const id = seed

  toasts.push({ id, message, tone })
  setTimeout(() => dismiss(id), timeout)

  return id
}
