const TONES = 6

function capitalize(word) {
  return word ? word.charAt(0).toUpperCase() + word.slice(1) : ''
}

export function displayName(user) {
  if (!user || !user.username) return ''

  return user.username
    .split(/[._\-\s]+/)
    .filter(Boolean)
    .map(capitalize)
    .join(' ')
}

export function firstName(user) {
  return displayName(user).split(' ')[0] || ''
}

export function initials(user) {
  const parts = displayName(user).split(' ').filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()

  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

export function toneClass(user) {
  const seedText = (user && (user.username || user.email)) || ''
  let hash = 0

  for (let index = 0; index < seedText.length; index += 1) {
    hash = (hash * 31 + seedText.charCodeAt(index)) >>> 0
  }

  return `tone-${hash % TONES}`
}

export function greeting(date = new Date()) {
  const hour = date.getHours()

  if (hour < 5) return 'Bonne nuit'
  if (hour < 12) return 'Bonjour'
  if (hour < 18) return 'Bon après-midi'
  return 'Bonsoir'
}

export const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
