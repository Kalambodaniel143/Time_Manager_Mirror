import { t } from '@/i18n/index.js'
// Libellés et couleurs des états renvoyés par le serveur.
export const STATUS = {
  pending: { label: t('En attente'), badge: 'badge-warn' },
  consented: { label: t('Accord du collègue'), badge: 'badge-warn' },
  approved: { label: t('Acceptée'), badge: 'badge-ok' },
  rejected: { label: t('Refusée'), badge: 'badge-danger' },
  cancelled: { label: t('Annulée'), badge: '' },
  open: { label: t('Ouverte'), badge: '' },
  validated: { label: t('Validée'), badge: 'badge-ok' },
  closed: { label: t('Clôturée'), badge: 'badge-danger' },
}
export const statusOf = (value) => STATUS[value] ?? { label: value ?? '—', badge: '' }

export const ABSENCE_KINDS = { leave: t('Congé'), sick: t('Maladie'), recup: t('Récupération') }
export const SHIFT_KINDS = { day: t('Jour'), night: t('Nuit'), oncall: t('Astreinte'), leave: t('Congé'), rest: t('Repos') }
