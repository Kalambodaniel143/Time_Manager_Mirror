import { allow, db, fail, isAdmin, save } from './mock/db.js'
import { server } from './mock/server.js'

// Recherche d'organisation et demandes d'adhésion du faux serveur
// (contrat : docs/CONTRAT_BACKEND_ORGANISATIONS.md).
const normalize = (name) => name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim().toLowerCase()
const emailTaken = (data, email) => data.users.some((u) => u.email === email.toLowerCase())
const randomId = () => Math.random().toString(36).slice(2, 10)

function change(fn) {
  const data = db()
  const result = fn(data)
  save(data)
  return result
}

function newUser(data, fields) {
  const user = { id: Math.max(0, ...data.users.map((u) => u.id)) + 1, username: fields.email, ...fields, email: fields.email.toLowerCase() }
  data.users.push(user)
  return user
}

const requestJson = (r, data) => ({ ...r, organization_name: data.organizations.find((o) => o.id === r.organization_id)?.name, reference: undefined })

export const mockOrgApi = {

  lookupOrganization: (name) => server(() => {
    const org = db().organizations.find((o) => normalize(o.name) === normalize(name))
    if (!org) throw fail(404, 'Aucune organisation ne porte ce nom. Vérifiez l’orthographe.')
    return { id: org.id, name: org.name }
  }, { isLogin: true }),

  createJoinRequest: ({ organization_id, profile }) => server(() => change((data) => {
    if (emailTaken(data, profile.email) || data.joinRequests.some((r) => r.profile.email === profile.email && r.status === 'pending')) {
      throw fail(409, 'Cette adresse a déjà un compte ou une demande en attente.')
    }
    const request = { id: randomId(), reference: randomId() + randomId(), organization_id, profile, status: 'pending', created_at: new Date().toISOString(), rejection_reason: null }
    data.joinRequests.push(request)
    return { ...requestJson(request, data), reference: request.reference }
  }), { isLogin: true }),

  joinRequestStatus: (reference) => server(() => {
    const data = db()
    const request = data.joinRequests.find((r) => r.reference === reference)
    if (!request) throw fail(404, 'Référence inconnue.')
    return { id: request.id, reference, organization_name: requestJson(request, data).organization_name, status: request.status, rejection_reason: request.rejection_reason }
  }, { isLogin: true }),

  listJoinRequests: (orgId) => server((me) => {
    allow(isAdmin(me) && me.organization_id === orgId)
    const data = db()
    return data.joinRequests.filter((r) => r.organization_id === orgId).map((r) => requestJson(r, data))
  }),

  approveJoinRequest: (orgId, id, password) => server((me) => change((data) => {
    allow(isAdmin(me) && me.organization_id === orgId)
    const request = data.joinRequests.find((r) => r.id === id && r.organization_id === orgId)
    if (!request || request.status !== 'pending') throw fail(409, 'Cette demande a déjà été traitée.')
    Object.assign(request, { status: 'approved', reviewed_at: new Date().toISOString() })
    const user = newUser(data, { ...request.profile, role: 'employee', organization_id: orgId, password })
    return { request: requestJson(request, data), user }
  })),

  rejectJoinRequest: (orgId, id, reason) => server((me) => change((data) => {
    allow(isAdmin(me) && me.organization_id === orgId)
    const request = data.joinRequests.find((r) => r.id === id && r.organization_id === orgId)
    if (!request || request.status !== 'pending') throw fail(409, 'Cette demande a déjà été traitée.')
    Object.assign(request, { status: 'rejected', rejection_reason: reason, reviewed_at: new Date().toISOString() })
    return requestJson(request, data)
  })),

}
