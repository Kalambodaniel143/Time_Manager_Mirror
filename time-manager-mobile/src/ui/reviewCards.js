import { t } from '@/i18n/index.js'
import { parseApiDate } from './dates.js'
import { dayMonth, hhmm } from './format.js'
import { ABSENCE_KINDS } from './statusLabels.js'

// Demandes du serveur -> cartes de décision { id, title, lines, status }.
const at = (value) => (value ? `${dayMonth(parseApiDate(value))} ${hhmm(parseApiDate(value))}` : '—')
const range = (p) => (p?.start ? `${at(p.start)} – ${hhmm(parseApiDate(p.end))}` : '—')

const BUILDERS = {
  // Corrections et absences en attente ; échanges une fois le collègue d'accord.
  corrections: { open: ['pending'], card: (c, who) => ({ title: who(c), lines: [t('Avant : {0}', [range(c.before)]), t('Proposé : {0}', [range(c.proposal)]), c.reason] }) },
  absences: { open: ['pending'], card: (a, who) => ({ title: `${who(a)} · ${ABSENCE_KINDS[a.kind] ?? a.kind}`, lines: [`${at(a.start)} → ${at(a.end)}`, a.reason] }) },
  swaps: { open: ['consented'], card: (s, who) => ({ title: t('Échange · {0}', [who(s)]), lines: [s.reason] }) },
}

export function reviewCards(kind, items, who) {
  const { open, card } = BUILDERS[kind]
  return (items ?? []).filter((x) => open.includes(x.status))
    .map((x) => ({ id: x.id, status: x.status, ...card(x, who), lines: card(x, who).lines.filter(Boolean) }))
}
