import { reactive, watch } from 'vue'
import { auth } from '../stores/auth'
import {
  EMPLOYEE_PLACES,
  EMPLOYEE_PLAN,
  JOURNAL,
  MANAGER_RIGHTS,
  NOTES,
  PAYROLL,
  PERSONAS,
  RULES,
  SHIFT_HOURS,
  TEAM,
  TEAM_PLAN,
} from '../mocks/org'
import { toDateInput } from '../utils/date'
import { addDays, longestRun, mondayOf } from '../utils/hours'
import { readJson, writeJson } from '../utils/session'

const STORAGE_KEY = 'tm-org'
function storageKey() { return auth.organizationSession ? `${STORAGE_KEY}:${auth.organizationSession.organization.id}` : STORAGE_KEY }
const PLAN_OFFSET_DAYS = 14
const PLAN_LENGTH = 14
const RIGHT_LABELS = { validate: 'valider les feuilles', correct: 'corriger les heures', publish: 'publier le planning' }
const RULE_LABELS = {
  maxConsecutiveNights: 'Nuits d’affilée au maximum',
  maxNightsPerWeek: 'Nuits par semaine au maximum',
  maxNightsPerMonth: 'Nuits par mois au maximum',
  overtimeThreshold: 'Heures sup. au-delà de (par semaine)',
  publishDaysAhead: 'Planning publié au moins (jours avant)',
}

function stamp(date, time) {
  const clock = time || `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
  return `${toDateInput(date)} ${clock}`
}

export function lastWeekMonday() {
  return addDays(mondayOf(), -7)
}

export function planStart() {
  return addDays(mondayOf(), PLAN_OFFSET_DAYS)
}

function freshState() {
  const lastWeek = toDateInput(lastWeekMonday())

  return {
    rules: { ...RULES },
    rights: MANAGER_RIGHTS.map((right) => ({ ...right })),
    journal: JOURNAL.map((item) => ({ at: stamp(addDays(new Date(), -item.daysAgo), item.time), text: item.text })),
    notes: Object.fromEntries(Object.entries(NOTES).map(([username, text]) => [`${username}:${lastWeek}`, text])),
    validated: {},
    swapRequests: [],
    teamPlan: {
      start: toDateInput(planStart()),
      rows: JSON.parse(JSON.stringify(TEAM_PLAN)),
      published: false,
    },
  }
}

function restore() {
  const state = freshState()
  const saved = readJson(storageKey(), null)
  if (!saved) return state

  return {
    rules: { ...state.rules, ...saved.rules },
    rights: Array.isArray(saved.rights) ? saved.rights : state.rights,
    journal: Array.isArray(saved.journal) ? saved.journal : state.journal,
    notes: { ...state.notes, ...saved.notes },
    validated: saved.validated || {},
    swapRequests: saved.swapRequests || [],
    teamPlan: saved.teamPlan && saved.teamPlan.start === state.teamPlan.start ? saved.teamPlan : state.teamPlan,
  }
}

export const org = reactive(restore())
watch(() => auth.organizationSession?.organization.id, () => Object.assign(org, restore()))

function persist() {
  writeJson(storageKey(), org)
}

function log(text) {
  org.journal.unshift({ at: stamp(new Date()), text })
}

export function personaFor(role) {
  return PERSONAS[role] || PERSONAS.employee
}

export function team() {
  return TEAM
}

export function memberOf(username) {
  return TEAM.members.find((member) => member.username === username) || null
}

export function employeePlan(today = new Date()) {
  const monday = mondayOf(today)
  const todayKey = toDateInput(today)
  let placeIndex = 0

  return EMPLOYEE_PLAN.map((kind, index) => {
    const date = addDays(monday, index)
    const shift = SHIFT_HOURS[kind] || null
    const place = kind === 'night' || kind === 'oncall' ? EMPLOYEE_PLACES[placeIndex++ % EMPLOYEE_PLACES.length] : null
    return { date, kind, shift, place, isToday: toDateInput(date) === todayKey }
  })
}

export function planPublishedOn(today = new Date()) {
  return addDays(mondayOf(today), -PLAN_OFFSET_DAYS)
}

export function nextShifts(today = new Date(), count = 2) {
  const todayKey = toDateInput(today)
  return employeePlan(today)
    .filter((day) => toDateInput(day.date) > todayKey && (day.kind === 'night' || day.kind === 'oncall'))
    .slice(0, count)
}

export function noteFor(username, weekKey) {
  return org.notes[`${username}:${weekKey}`] || ''
}

export function setNote(username, weekKey, text) {
  org.notes[`${username}:${weekKey}`] = text
  persist()
}

export function isValidated(username, weekKey) {
  return Boolean(org.validated[`${username}:${weekKey}`])
}

export function validateSheets(usernames, weekKey) {
  usernames.forEach((username) => {
    org.validated[`${username}:${weekKey}`] = true
  })
  persist()
}

export function teamPlanDays() {
  const start = new Date(`${org.teamPlan.start}T00:00:00`)
  return Array.from({ length: PLAN_LENGTH }, (_, index) => addDays(start, index))
}

export function teamPlanRows() {
  return Object.entries(org.teamPlan.rows)
    .map(([username, shifts]) => ({ ...memberOf(username), shifts }))
    .filter((row) => row.username)
}

function runOf(shifts) {
  return longestRun(shifts, 'night')
}

export function nightRun(shifts) {
  return runOf(shifts).length
}

function swapCandidate(rows, offender, index) {
  const max = org.rules.maxConsecutiveNights

  return rows.find((row) => {
    if (row.username === offender.username) return false
    if (row.shifts[index] !== 'day' || row.shifts[index - 1] === 'night') return false

    const swapped = [...row.shifts]
    swapped[index] = 'night'
    return runOf(swapped).length <= max
  })
}

export function planAlerts() {
  const max = org.rules.maxConsecutiveNights
  const rows = teamPlanRows()

  return rows
    .map((row) => ({ row, run: runOf(row.shifts) }))
    .filter(({ run }) => run.length > max)
    .map(({ row, run }) => {
      const index = run.start + max
      return { member: row, run, index, partner: swapCandidate(rows, row, index) || null }
    })
}

export function swapShifts(usernameA, usernameB, index) {
  const rowA = org.teamPlan.rows[usernameA]
  const rowB = org.teamPlan.rows[usernameB]
  if (!rowA || !rowB) return

  const kept = rowA[index]
  rowA[index] = rowB[index]
  rowB[index] = kept
  org.teamPlan.published = false
  persist()
}

export function setShift(username, index, kind) {
  const row = org.teamPlan.rows[username]
  if (!row) return

  row[index] = kind
  org.teamPlan.published = false
  persist()
}

export function canPublish(managerId = 'lucie') {
  const right = org.rights.find((item) => item.id === managerId)
  return Boolean(right && right.publish)
}

export function publishPlan() {
  org.teamPlan.published = true
  persist()
}

export function setRight(managerId, key, value) {
  const right = org.rights.find((item) => item.id === managerId)
  if (!right || right[key] === value) return

  right[key] = value
  log(`${right.name} ${value ? 'peut' : 'ne peut plus'} ${RIGHT_LABELS[key]} (${right.team}). Changement enregistré localement.`)
  persist()
}

export function setRule(key, value) {
  const number = Number(value)
  if (!Object.hasOwn(RULE_LABELS, key) || !Number.isInteger(number) || number < (['maxNightsPerWeek', 'maxNightsPerMonth'].includes(key) ? 0 : 1) || org.rules[key] === number) return

  const previous = org.rules[key]
  org.rules[key] = number
  log(`${RULE_LABELS[key]} : ${previous} → ${number}. Changement enregistré localement.`)
  persist()
}

export function payroll() {
  const rows = PAYROLL.map((row) => ({
    ...row,
    total: row.day + row.night + row.sup + row.recup + row.oncall + row.leave,
  }))
  const totals = rows.reduce(
    (sum, row) => {
      Object.keys(sum).forEach((key) => {
        sum[key] += row[key]
      })
      return sum
    },
    { day: 0, night: 0, sup: 0, recup: 0, oncall: 0, leave: 0, total: 0 },
  )
  return { rows, totals }
}

export function payrollCsv() {
  const { rows } = payroll()
  const header = 'Service;Jour;Nuit x1,5;Sup. x2;Récup;Astreinte;Congé;Total'
  const lines = rows.map((row) =>
    [row.service, row.day, row.night, row.sup, row.recup, row.oncall, row.leave, row.total].join(';'),
  )
  return [header, ...lines].join('\n')
}

export function resetOrg() {
  Object.assign(org, freshState())
  persist()
}

export function requestShiftSwap(user, day, reason) {
  if (!day || !reason.trim()) throw new Error('Choisissez une garde et indiquez votre demande.')
  if (org.swapRequests.some(item => item.user_id === user.id && item.day === day && item.status === 'pending')) throw new Error('Une demande est déjà en attente pour cette garde.')
  const item = { id: crypto.randomUUID(), user_id: user.id, username: user.username, day, reason: reason.trim(), status: 'pending', created_at: new Date().toISOString() }
  org.swapRequests.unshift(item); persist(); return item
}
export function resolveShiftSwap(id, status) {
  if (!['accepted', 'rejected'].includes(status)) return
  const item = org.swapRequests.find(request => request.id === id)
  if (!item || item.status !== 'pending') return
  item.status = status; item.reviewed_at = new Date().toISOString(); persist()
}
