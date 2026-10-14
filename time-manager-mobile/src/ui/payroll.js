import { parseApiDate } from './dates.js'

// Relevé mensuel calculé comme le backend (contrat, section 13) :
// - périodes découpées en UTC aux limites du mois, de la semaine et de la nuit (22 h – 6 h) ;
// - catégories exclusives : jour, nuit, heures sup. (au-delà du seuil hebdomadaire, sans
//   majoration de nuit en plus), récup et astreinte (hors heures sup.) ;
// - la semaine qui commence le mois précédent compte pour le seuil ;
// - congés / maladie : heures rémunérables confirmées, au prorata du mois, hors total travaillé.
const HOUR = 3_600_000
const DAY = 24 * HOUR
export const CATEGORIES = ['day', 'night', 'sup', 'recup', 'oncall', 'leave']

export function monthBounds(month) {
  const from = Date.parse(`${month}-01T00:00:00Z`)
  const next = new Date(from)
  next.setUTCMonth(next.getUTCMonth() + 1)
  return [from, next.getTime()]
}
const weekStart = (ms) => { const d = new Date(ms); d.setUTCHours(0, 0, 0, 0); return d.getTime() - ((d.getUTCDay() + 6) % 7) * DAY }

// Coupe [a, b[ aux frontières de nuit (22 h et 6 h UTC) et de semaine.
function slices(a, b) {
  const cuts = []
  for (let d = weekStart(a) - DAY; d < b; d += DAY) cuts.push(d, d + 6 * HOUR, d + 22 * HOUR)
  const points = [a, ...cuts.filter((c) => c > a && c < b), b].sort((x, y) => x - y)
  return points.slice(1).map((end, i) => {
    const start = points[i]
    const hour = new Date(start).getUTCHours()
    return { start, end, night: hour >= 22 || hour < 6 }
  })
}

const clip = (a, b, from, next) => Math.max(0, Math.min(b, next) - Math.max(a, from))

// Heures (en h, arrondies au centième) d'un agent pour le mois « AAAA-MM ».
export function monthSummary(workingTimes, month, { threshold = 40, absences = [] } = {}) {
  const [from, next] = monthBounds(month)
  const sums = Object.fromEntries(CATEGORIES.map((c) => [c, 0]))
  const days = new Set()
  let count = 0
  const periods = (workingTimes ?? []).filter((p) => p.end)
    .map((p) => ({ kind: p.kind ?? 'work', start: parseApiDate(p.start).getTime(), end: parseApiDate(p.end).getTime() }))
    .filter((p) => p.end > weekStart(from) && p.start < next)
    .sort((x, y) => x.start - y.start)
  const weekly = new Map() // semaine -> heures de travail déjà comptées
  for (const p of periods) {
    if (clip(p.start, p.end, from, next)) { count += 1; days.add(new Date(Math.max(p.start, from)).toISOString().slice(0, 10)) }
    if (p.kind !== 'work') { sums[p.kind === 'oncall' ? 'oncall' : 'recup'] += clip(p.start, p.end, from, next); continue }
    for (const s of slices(p.start, p.end)) {
      const week = weekStart(s.start)
      const done = weekly.get(week) ?? 0
      const free = Math.max(0, threshold * HOUR - done)
      const normalEnd = Math.min(s.end, s.start + free)
      weekly.set(week, done + (s.end - s.start))
      sums[s.night ? 'night' : 'day'] += clip(s.start, normalEnd, from, next)
      sums.sup += clip(normalEnd, s.end, from, next)
    }
  }
  for (const a of absences) {
    if (a.status !== 'approved' || !['leave', 'sick'].includes(a.kind) || !a.payable_hours) continue
    const [start, end] = [parseApiDate(a.start).getTime(), parseApiDate(a.end).getTime()]
    if (end > start) sums.leave += Number(a.payable_hours) * HOUR * (clip(start, end, from, next) / (end - start))
  }
  const h = (ms) => Math.round((ms / HOUR) * 100) / 100
  const result = Object.fromEntries(CATEGORIES.map((c) => [c, h(sums[c])]))
  result.total = h(sums.day + sums.night + sums.sup + sums.recup + sums.oncall)
  return { ...result, days: days.size, periods: count }
}

// Additionne plusieurs résumés (une équipe, toute l'organisation).
export function addUp(summaries) {
  const keys = [...CATEGORIES, 'total', 'periods']
  return Object.fromEntries(keys.map((k) => [k, Math.round(summaries.reduce((s, x) => s + (x[k] ?? 0), 0) * 100) / 100]))
}

// Relevé CSV (une ligne par agent), lisible par un tableur.
export function toCsv(rows, labels) {
  const head = ['Agent', 'E-mail', 'Service', ...CATEGORIES.map((c) => labels[c]), 'Total']
  const lines = rows.map((r) => [r.name, r.email, r.team, ...CATEGORIES.map((c) => r[c]), r.total])
  return [head, ...lines].map((cells) => cells.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(';')).join('\n')
}

// Nombre d'heures lisible : « 151,5 h ».
export const formatHours = (value, locale) => `${Number(value).toLocaleString(locale, { maximumFractionDigits: 1 })} h`
