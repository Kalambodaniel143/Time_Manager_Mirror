import { allow, change, db, fail, findUser, isAdmin, managedIds, passwordOf, publicUser, sameOrg } from './mock/db.js'
import { server } from './mock/server.js'

// Comptes du faux serveur (règles de user_controller.ex et organization_controller.ex).
const PROFILE = ['username', 'email', 'first_name', 'last_name']
const admins = (data) => data.users.filter((u) => u.role === 'administrator' && u.organization_id)
const pick = (attrs) => Object.fromEntries(PROFILE.filter((k) => attrs[k] !== undefined).map((k) => [k, attrs[k]]))
const adminOf = (me, id) => isAdmin(me) && sameOrg(me, findUser(id))
const lastAdmin = (data, user) => user.role === 'administrator' && admins(data).filter((u) => sameOrg(u, user)).length === 1

function checkPassword(value) {
  if (value.length < 8 || value.length > 128) throw fail(422, 'password should be at least 8 character(s)')
}

export const mockUsersApi = {
  getUsers: () => server((me) => {
    if (isAdmin(me)) return db().users.filter((u) => sameOrg(u, me)).map(publicUser)
    allow(me.role === 'manager')
    return [me, ...managedIds(me.id).map(findUser)].map(publicUser)
  }),
  getRoles: () => server(() => ['employee', 'manager', 'administrator'].map((name, i) => ({ id: i + 1, name }))),
  getMembers: (orgId) => server((me) => {
    allow(isAdmin(me) && me.organization_id === orgId)
    return db().users.filter((u) => u.organization_id === orgId).map(publicUser)
  }),

  createUser: (attrs) => server((me) => change((data) => {
    allow(isAdmin(me))
    if (data.users.some((u) => u.email === attrs.email.toLowerCase())) throw fail(422, 'email has already been taken')
    checkPassword(attrs.password ?? '')
    const user = { id: Math.max(...data.users.map((u) => u.id)) + 1, ...pick(attrs), email: attrs.email.toLowerCase(),
      role: attrs.role ?? 'employee', organization_id: me.organization_id, password: attrs.password }
    data.users.push(user)
    return publicUser(user)
  })),

  // Profil + mot de passe : son propre mot de passe exige current_password ; l'admin réinitialise celui d'un autre.
  updateUser: (id, attrs) => server((me) => change((data) => {
    allow(me.id === Number(id) || adminOf(me, id))
    const user = data.users.find((u) => u.id === Number(id))
    if (attrs.email !== undefined && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(attrs.email)) throw fail(422, 'email has invalid format')
    if (attrs.password) {
      if (me.id === user.id && attrs.current_password !== passwordOf(user)) throw fail(422, 'current_password is not valid')
      checkPassword(attrs.password)
      user.password = attrs.password
    }
    return publicUser(Object.assign(user, pick(attrs)))
  })),

  updateRole: (id, role) => server((me) => change((data) => {
    allow(adminOf(me, id) && me.id !== Number(id))
    const user = data.users.find((u) => u.id === Number(id))
    if (lastAdmin(data, user)) throw fail(409, 'The last administrator cannot be demoted or deleted')
    return publicUser(Object.assign(user, { role }))
  })),
  setMemberRole: (orgId, id, role) => server((me) => change((data) => {
    allow(isAdmin(me) && me.organization_id === orgId && ['employee', 'manager'].includes(role))
    const user = data.users.find((u) => u.id === Number(id) && u.organization_id === orgId)
    allow(user && user.role !== 'administrator')
    return publicUser(Object.assign(user, { role }))
  })),

  // Soi-même (avec son mot de passe) ou un membre de son organisation (administration).
  deleteUser: (id, currentPassword) => server((me) => change((data) => {
    const user = data.users.find((u) => u.id === Number(id))
    allow(user && (me.id === user.id || adminOf(me, id)))
    if (me.id === user.id && currentPassword !== passwordOf(user)) throw fail(422, 'current_password is not valid')
    if (lastAdmin(data, user)) throw fail(409, 'The last administrator cannot be demoted or deleted')
    data.users = data.users.filter((u) => u.id !== user.id)
    data.teams.forEach((t) => { t.memberIds = t.memberIds.filter((m) => m !== user.id) })
    return null
  })),
}
