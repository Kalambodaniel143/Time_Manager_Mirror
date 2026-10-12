// Type de garde, comme les étiquettes de la maquette (Jour, Nuit ×1,5…).
export const SHIFT_LABELS = { jour: 'Jour', nuit: 'Nuit ×1,5', astreinte: 'Astreinte', repos: 'Repos' }

// Règle simple côté mobile : une garde qui commence entre 20 h et 5 h est une nuit.
export function shiftType(start) {
  const h = new Date(start).getHours()
  return h >= 20 || h < 5 ? 'nuit' : 'jour'
}

// Plus longue suite de nuits sur des jours consécutifs.
export function maxConsecutiveNights(periods) {
  const nights = periods.filter((p) => shiftType(p.start) === 'nuit')
  const days = [...new Set(nights.map((p) => Math.floor(new Date(p.start).setHours(12) / 86_400_000)))]
    .sort((a, b) => a - b)
  let best = 0
  let run = 0
  days.forEach((d, i) => { run = i && d === days[i - 1] + 1 ? run + 1 : 1; best = Math.max(best, run) })
  return best
}
