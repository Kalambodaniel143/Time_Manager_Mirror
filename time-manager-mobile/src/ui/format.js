import { locale, t } from '@/i18n/index.js'
// Mise en forme des textes affichés (français).
const pad = (n) => String(n).padStart(2, '0')

export const hhmm = (date) => {
  const d = new Date(date)
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`
}

export const clock = (ms) => {
  const s = Math.max(0, Math.floor(ms / 1000))
  return `${pad(Math.floor(s / 3600))}:${pad(Math.floor(s / 60) % 60)}:${pad(s % 60)}`
}

export const hours = (ms) => {
  const m = Math.round(ms / 60000)
  return m % 60 ? `${Math.floor(m / 60)} h ${pad(m % 60)}` : `${m / 60} h`
}

export const longDate = (date) =>
  capitalize(new Date(date).toLocaleDateString(locale(), { weekday: 'long', day: 'numeric', month: 'long' }))

export const shortDay = (date) =>
  capitalize(new Date(date).toLocaleDateString(locale(), { weekday: 'short', day: 'numeric' }))

export const dayMonth = (date) =>
  new Date(date).toLocaleDateString(locale(), { day: 'numeric', month: 'short' })

export function ago(date) {
  const min = Math.round((Date.now() - new Date(date)) / 60000)
  if (min < 1) return t('à l’instant')
  if (min < 60) return t('il y a {0} min', [min])
  if (min < 1440) return t('il y a {0} h', [Math.round(min / 60)])
  return t('le {0} à {1}', [dayMonth(date), hhmm(date)])
}

// Nom affiché : prénom + nom si le serveur les connaît, sinon l'identifiant.
export const displayName = (user) =>
  [user?.first_name, user?.last_name].filter(Boolean).join(' ') || user?.email || ''

// « 1 agent », « 3 agents ».
export const plural = (n, word) => `${n} ${word}${n > 1 ? 's' : ''}`

export const initials = (name = '') =>
  name.split(/\s+/).map((w) => w[0]).join('').slice(0, 2).toUpperCase()

export const ROLE_LABELS = { employee: t('Agent'), manager: t('Responsable'), administrator: t('Administration') }
export const KIND_LABELS = { arrival: t('Arrivée'), departure: t('Départ'), pause: t('Pause'), resume: t('Reprise') }

function capitalize(text) {
  return text.charAt(0).toUpperCase() + text.slice(1)
}
