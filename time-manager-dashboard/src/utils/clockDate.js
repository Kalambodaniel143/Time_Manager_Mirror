// Les dates sans fuseau provenant de Phoenix sont interprétées en UTC.
export function formatClockDate(value) {
  let input = value
  if (typeof input === 'string' && /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}$/.test(input)) {
    input = `${input.replace(' ', 'T')}Z`
  }
  if (!(input instanceof Date) && typeof input !== 'string') {
    throw new Error('Date de pointage invalide')
  }
  const date = input instanceof Date ? input : new Date(input)
  if (Number.isNaN(date.getTime())) throw new Error('Date de pointage invalide')
  return date.toISOString().slice(0, 19).replace('T', ' ')
}
