import { t } from '@/i18n/index.js'

// Le serveur enregistre des codes techniques (« sheet.validated ») : on les traduit pour le journal.
// Phrases connues d'abord, sinon « Objet : action » (ex. « Planning : suppression »).
const PHRASES = {
  'sheet.validated': t('Semaine validée'),
  'sheet.close': t('Semaine clôturée'),
  'sheet.reopen': t('Semaine rouverte'),
  'note.updated': t('Note de semaine modifiée'),
  'correction.requested': t('Correction d’heures demandée'),
  'correction.approved': t('Correction d’heures acceptée'),
  'correction.rejected': t('Correction d’heures refusée'),
  'plan.created': t('Planning créé'),
  'plan.updated': t('Planning modifié'),
  'plan.published': t('Planning publié'),
  'plan.deleted': t('Planning supprimé'),
  'shift.saved': t('Créneau enregistré'),
  'shift.deleted': t('Créneau supprimé'),
}

const OBJECTS = {
  sheet: t('Semaine'), note: t('Note de semaine'), correction: t('Correction d’heures'), plan: t('Planning'),
  shift: t('Créneau'), swap: t('Échange de créneau'), absence: t('Absence'), rules: t('Règles'),
  join_request: t('Demande pour rejoindre'), permissions: t('Droits d’équipe'), user: t('Compte'), member: t('Membre'), team: t('Équipe'), password: t('Mot de passe'),
}
const ACTIONS = {
  created: t('création'), saved: t('enregistrement'), updated: t('modification'), deleted: t('suppression'),
  published: t('publication'), requested: t('demande'), approved: t('acceptation'), rejected: t('refus'),
  cancelled: t('annulation'), validated: t('validation'), close: t('clôture'), reopen: t('réouverture'), consent: t('accord'),
}

export function auditLabel(code = '') {
  if (PHRASES[code]) return PHRASES[code]
  const [object, action] = code.split('.')
  if (!OBJECTS[object] && !ACTIONS[action]) return code
  return t('{0} : {1}', [OBJECTS[object] ?? object, ACTIONS[action] ?? action ?? ''])
}
