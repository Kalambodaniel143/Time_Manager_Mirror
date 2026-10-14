import { t } from '@/i18n/index.js'
import { sameDay, startOfDay } from './dates.js'

// Actions permises après chaque pointage (copie de @next_kinds dans clocks.ex).
export const NEXT_KINDS = {
  none: ['arrival'],
  arrival: ['pause', 'departure'],
  resume: ['pause', 'departure'],
  pause: ['resume', 'departure'],
  departure: ['arrival'],
}

const isStart = (kind) => kind === 'arrival' || kind === 'resume'

// Résume une liste de pointages triés : statut, arrivée, temps travaillé aujourd'hui.
export function summarize(events, now = new Date()) {
  const last = events.at(-1)
  const open = last && last.kind !== 'departure'
  const service = open ? events.slice(events.findLastIndex((e) => e.kind === 'arrival')) : []

  // Temps travaillé aujourd'hui = toutes les périodes du jour (pauses exclues),
  // y compris les services déjà terminés et la part d'une nuit commencée la veille.
  const today = startOfDay(now)
  const overlap = (from, to) => Math.max(0, Math.min(to, now) - Math.max(from, today))
  let worked = 0
  let from = null
  for (const e of events) {
    if (isStart(e.kind)) from = new Date(e.time)
    else if (from) { worked += overlap(from, new Date(e.time)); from = null }
  }
  const running = from !== null
  if (running) worked += overlap(from, now)

  const arrival = service[0]?.time ?? null
  return {
    last: last ?? null,
    allowed: NEXT_KINDS[last?.kind ?? 'none'],
    arrival,
    worked,                 // temps travaillé aujourd'hui au moment du calcul
    running,                // le compteur tourne (pas en pause)
    // Service ouvert depuis un autre jour : le départ a été oublié.
    missingDeparture: Boolean(arrival && !sameDay(arrival, now) && now - new Date(arrival) > 16 * 3600_000),
  }
}

export function statusLabel(last, now = new Date()) {
  if (!last || (last.kind === 'departure' && !sameDay(last.time, now))) return t('Pas encore pointé aujourd’hui')
  return { arrival: t('Service en cours'), resume: t('Service en cours'), pause: t('En pause'), departure: t('Service terminé') }[last.kind]
}
