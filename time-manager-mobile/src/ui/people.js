import { t } from '@/i18n/index.js'
import { displayName } from './format.js'

// Nom d'une personne citée dans une réponse du serveur (demande, garde, événement…).
// Le serveur donne selon les routes un objet user, un username, ou seulement user_id.
export function personName(item, people = [], key = 'user') {
  const embedded = item?.[key]
  if (embedded && typeof embedded === 'object') return displayName(embedded)
  const id = item?.[`${key}_id`]
  const known = people.find((p) => p.id === id)
  return known ? displayName(known) : item?.[`${key}name`] || item?.username || (id ? t('Agent n° {0}', [id]) : '—')
}
