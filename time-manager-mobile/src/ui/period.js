import { addDays, localDay, mondayOf } from './dates.js'

// Périodes proposées par le sélecteur des tableaux de bord.
export const PRESETS = [
  { label: 'Cette semaine', make: (today) => ({ from: mondayOf(today), to: today, unit: 'day' }) },
  { label: '4 semaines', make: (today) => ({ from: addDays(today, -27), to: today, unit: 'week' }) },
  { label: '3 mois', make: (today) => ({ from: addDays(today, -89), to: today, unit: 'week' }) },
]

// Le modèle garde des dates « AAAA-MM-JJ » (format des champs date natifs).
export function preset(index) {
  const { from, to, unit } = PRESETS[index].make(new Date())
  return { from: localDay(from), to: localDay(to), unit }
}

export const toRange = (period) => ({ from: new Date(`${period.from}T00:00`), to: new Date(`${period.to}T00:00`) })
