import { listUsers } from './userService'
import { listTeams } from './teamService'
import { getWorkingTimes } from './workingTimeService'
import { displayName } from '../utils/people'
import { toDateInput } from '../utils/date'
import { clockDate } from '../utils/missingDeparture'
import { addDays } from '../utils/hours'

// Clip periods at the report boundaries. A service crossing midnight or a
// month boundary contributes only its overlap with the displayed interval.
export function hoursBetween(entries, from, to) {
  const lower = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate())
  const upper = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate())
  return entries.reduce((sum, entry) => {
    const start = clockDate(entry.start), end = clockDate(entry.end)
    if (end < start) throw new Error('Une période de travail contient des horaires invalides.')
    return sum + Math.max(0, Math.min(end.getTime(), upper) - Math.max(start.getTime(), lower)) / 3600000
  }, 0)
}

export function dailyHours(entries, monday) {
  return Array.from({ length: 7 }, (_, index) => {
    const date = addDays(monday, index)
    return { date, key: toDateInput(date), hours: hoursBetween(entries, date, addDays(date, 1)) }
  })
}

export async function monthlyReport(from) {
  const to = new Date(from.getFullYear(), from.getMonth() + 1, 1)
  const [users, teams] = await Promise.all([listUsers(), listTeams()])
  if (!Array.isArray(users) || !Array.isArray(teams)) throw new Error('Liste des comptes ou équipes invalide.')
  const uniqueUsers = [...new Map(users.map(user => [user.id, user])).values()]
  const rows = []
  // Bound simultaneous requests; a failed read aborts the report instead of
  // silently exporting incomplete totals.
  for (let offset = 0; offset < uniqueUsers.length; offset += 4) {
    rows.push(...await Promise.all(uniqueUsers.slice(offset, offset + 4).map(async user => {
      const entries = await getWorkingTimes(user.id)
      if (!Array.isArray(entries)) throw new Error('Liste des heures invalide.')
      return {
        id: user.id, name: displayName(user), email: user.email,
        teams: teams.filter(team => team.manager?.id === user.id || team.members.some(member => member.id === user.id)).map(team => team.name).join(', '),
        total: hoursBetween(entries, from, to),
      }
    })))
  }
  return { rows, total: rows.reduce((sum, row) => sum + row.total, 0) }
}

export function reportCsv(report) {
  function cell(value) {
    let text = String(value ?? '')
    if (/^[\s]*[=+@-]/.test(text)) text = `'${text}`
    return `"${text.replaceAll('"', '""')}"`
  }
  return ['Nom;E-mail;Équipes;Heures enregistrées', ...report.rows.map(row => [row.name, row.email, row.teams, row.total.toFixed(2).replace('.', ',')].map(cell).join(';'))].join('\n')
}
