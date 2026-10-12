import { DAY_MS, addDays, localDay, mondayOf, parseApiDate, startOfDay } from './dates.js'
import { shiftType } from './shifts.js'
import { dayMonth, shortDay } from './format.js'

// Heures travaillées de l'API -> { start: Date, end: Date }
export const toPeriods = (workingTimes) =>
  (workingTimes ?? []).map((p) => ({ id: p.id, start: parseApiDate(p.start), end: parseApiDate(p.end) }))

const duration = (list) => list.reduce((total, p) => total + (p.end - p.start), 0)
const inRange = (periods, from, to) => periods.filter((p) => p.start >= from && p.start < addDays(to, 1))

// Une barre par jour ou par semaine sur [from, to], heures de jour / de nuit.
export function aggregate(periods, from, to, unit) {
  const bars = []
  for (let d = unit === 'week' ? mondayOf(from) : startOfDay(from); d <= to; d = addDays(d, unit === 'week' ? 7 : 1)) {
    const end = addDays(d, unit === 'week' ? 7 : 1)
    const label = unit === 'week' ? dayMonth(d) : shortDay(d)
    const slice = periods.filter((p) => p.start >= d && p.start < end)
    const night = duration(slice.filter((p) => shiftType(p.start) === 'nuit'))
    bars.push({ label, jour: duration(slice) - night, nuit: night })
  }
  return bars
}

// Totaux et moyennes d'un agent sur la période.
export function stats(periods, from, to) {
  const list = inRange(periods, from, to)
  const total = duration(list)
  const days = new Set(list.map((p) => localDay(p.start))).size
  const weeks = Math.max(1, (addDays(to, 1) - from) / (7 * DAY_MS))
  const night = duration(list.filter((p) => shiftType(p.start) === 'nuit'))
  return { total, night, days, perDay: days ? total / days : 0, perWeek: total / weeks }
}

// Moyennes d'une équipe : par agent et par jour travaillé, par agent et par semaine.
export function teamStats(memberPeriods, from, to) {
  const each = memberPeriods.map((periods) => stats(periods, from, to))
  const total = each.reduce((s, x) => s + x.total, 0)
  const days = each.reduce((s, x) => s + x.days, 0)
  const count = Math.max(1, each.length)
  return {
    total,
    night: each.reduce((s, x) => s + x.night, 0),
    perDay: days ? total / days : 0,
    perWeek: each.reduce((s, x) => s + x.perWeek, 0) / count,
  }
}

// Barres moyennes par agent pour l'équipe.
export function teamAggregate(memberPeriods, from, to, unit) {
  const count = Math.max(1, memberPeriods.length)
  const all = memberPeriods.map((periods) => aggregate(periods, from, to, unit))
  return (all[0] ?? aggregate([], from, to, unit)).map((bar, i) => ({
    label: bar.label,
    jour: all.reduce((s, bars) => s + bars[i].jour, 0) / count,
    nuit: all.reduce((s, bars) => s + bars[i].nuit, 0) / count,
  }))
}
