import { t } from '@/i18n/index.js'
import { api } from './source.js'
import { app } from './appState.js'
import { handleError, isUnreachable, reportServer } from './network.js'
import { clearSession, readSession, saveSession } from '@/storage/sessionStorage.js'
import { restoreSession } from './authService.js'

// Actions de gestion (profil, comptes, rôles, équipes, heures) : elles demandent le serveur.
// Contrairement aux pointages, elles ne sont pas mises en file d'attente.
const MESSAGES = {
  forbidden: t('Le serveur n’autorise pas cette action pour votre rôle.'),
  conflict: t('Action refusée : il doit rester au moins un administrateur.'),
}

async function online(call) {
  try {
    const result = await call()
    reportServer(true)
    return result
  } catch (error) {
    handleError(error)
    if (isUnreachable(error) || !error.kind) throw new Error(t('Connexion au serveur nécessaire pour cette action.'))
    if (error.message.includes('current_password')) throw new Error(t('Mot de passe actuel incorrect.'))
    throw new Error(MESSAGES[error.kind] ?? error.message)
  }
}

const me = () => app.user.id

// Mon compte
export async function updateProfile(attrs) {
  const user = await online(() => api.updateUser(me(), attrs))
  saveSession({ ...readSession(), user: { ...app.user, ...user } })
  restoreSession()
}
export const changePassword = (current, next) => online(() => api.updateUser(me(), { password: next, current_password: current }))
export async function deleteOwnAccount(currentPassword) {
  await online(() => api.deleteUser(me(), currentPassword))
  clearSession() // le serveur a déjà supprimé le cookie de session
  restoreSession()
}

// Administration des comptes
export const updateUser = (id, attrs) => online(() => api.updateUser(id, attrs))
export const resetPassword = (id, password) => online(() => api.updateUser(id, { password }))
export const deleteUser = (id) => online(() => api.deleteUser(id))
// Employé ⇄ manager : route des membres de l'organisation ; administrateur : route des rôles.
export const changeRole = (id, role) => online(() => (app.organization && role !== 'administrator'
  ? api.setMemberRole(app.organization.id, id, role)
  : api.updateRole(id, role)))

// Équipes
export const createTeam = (team) => online(() => api.createTeam(team))
export const updateTeam = (id, team) => online(() => api.updateTeam(id, team))
export const deleteTeam = (id) => online(() => api.deleteTeam(id))
export const addMember = (id, userId) => online(() => api.addMember(id, userId))
export const removeMember = (id, userId) => online(() => api.removeMember(id, userId))

// Corrections d'heures (responsable : son équipe, pas soi · administration : l'organisation)
export const addPeriod = (userId, period) => online(() => api.createWorkingTime(userId, period))
export const editPeriod = (id, period) => online(() => api.updateWorkingTime(id, period))
export const removePeriod = (id) => online(() => api.deleteWorkingTime(id))
