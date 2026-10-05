import { createRouter, createWebHistory } from 'vue-router'
import Authentication from '../components/Authentication.vue'
import ChartManager from '../components/ChartManager.vue'
import ClockManager from '../components/ClockManager.vue'
import Profile from '../components/Profile.vue'
import Registration from '../components/Registration.vue'
import WorkingTime from '../components/WorkingTime.vue'
import WorkingTimes from '../components/WorkingTimes.vue'
import { configureHttp } from '../services/http'
import { auth, clearSession, fetchMe, hasRole, isSelf } from '../stores/auth'
import { notify } from '../utils/toast'
import { homeFor } from '../utils/session'
import AdminTeams from '../views/AdminTeams.vue'
import AdminUsers from '../views/AdminUsers.vue'
import EmployeePlanning from '../views/EmployeePlanning.vue'
import EmployeeToday from '../views/EmployeeToday.vue'
import PayrollMonth from '../views/PayrollMonth.vue'
import TeamOverview from '../views/TeamOverview.vue'
import TeamPlanning from '../views/TeamPlanning.vue'
import TeamsRights from '../views/TeamsRights.vue'

const EVERYONE = ['employee', 'manager', 'administrator']
const MANAGERS = ['manager', 'administrator']
const ADMINS = ['administrator']

// meta.public: reachable without a session. meta.roles: the roles allowed.
// meta.userParam: the route shows one user's data; an employee only sees their own.
const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/connexion', name: 'login', component: Authentication, meta: { public: true } },
    { path: '/inscription', name: 'register', component: Registration, meta: { public: true } },
    { path: '/profil', name: 'profile', component: Profile, meta: { roles: EVERYONE } },
    { path: '/', name: 'overview', component: EmployeeToday, meta: { roles: ['employee'] } },
    { path: '/planning', name: 'planning', component: EmployeePlanning, meta: { roles: ['employee'] } },
    {
      path: '/workingTimes/:userID',
      name: 'workingTimes',
      component: WorkingTimes,
      props: (route) => ({ userID: route.params.userID }),
      meta: { roles: EVERYONE, userParam: 'userID' },
    },
    {
      path: '/workingTime/:userid',
      name: 'workingTimeCreate',
      component: WorkingTime,
      props: (route) => ({ userId: route.params.userid, open: true }),
      meta: { roles: MANAGERS, userParam: 'userid' },
    },
    {
      path: '/workingTime/:userid/:workingtimeid',
      name: 'workingTimeEdit',
      component: WorkingTime,
      props: (route) => ({
        userId: route.params.userid,
        workingTimeId: route.params.workingtimeid,
        open: true,
      }),
      meta: { roles: MANAGERS, userParam: 'userid' },
    },
    {
      path: '/clock/:userid',
      name: 'clock',
      component: ClockManager,
      props: (route) => ({ userId: route.params.userid }),
      // Everyone clocks for themselves only.
      meta: { roles: EVERYONE, userParam: 'userid', selfOnly: true },
    },
    {
      path: '/chartManager/:userid',
      name: 'chartManager',
      component: ChartManager,
      props: (route) => ({ userId: route.params.userid }),
      meta: { roles: EVERYONE, userParam: 'userid' },
    },
    { path: '/equipe', name: 'team', component: TeamOverview, meta: { roles: MANAGERS } },
    { path: '/equipe/planning', name: 'teamPlanning', component: TeamPlanning, meta: { roles: MANAGERS } },
    { path: '/admin/paie', name: 'payroll', component: PayrollMonth, meta: { roles: ADMINS } },
    { path: '/admin/utilisateurs', name: 'adminUsers', component: AdminUsers, meta: { roles: ADMINS } },
    { path: '/equipes', name: 'adminTeams', component: AdminTeams, meta: { roles: MANAGERS } },
    { path: '/admin/droits', name: 'rights', component: TeamsRights, meta: { roles: ADMINS } },
    { path: '/:pathMatch(.*)*', redirect: { name: 'overview' } },
  ],
})

// Every API call carries the CSRF token; a 401 means the session is gone.
configureHttp({
  csrfToken: () => auth.csrfToken,
  onUnauthorized: () => {
    if (!auth.user) return

    clearSession()
    notify('Votre session a expiré. Reconnectez-vous.', 'error')
    router.push({ name: 'login', query: { redirect: router.currentRoute.value.fullPath } })
  },
})

function denied(role) {
  notify('Accès refusé : cette page ne fait pas partie de vos droits.', 'error')
  return homeFor(role)
}

// Runs before every page change. It only improves the experience: the API
// checks the same rules again on every request, and has the final word.
router.beforeEach(async (to) => {
  if (!auth.checked) await fetchMe()

  const user = auth.user

  if (to.meta.public) return user ? homeFor(user.role) : true
  if (!user) return { name: 'login', query: to.fullPath === '/' ? {} : { redirect: to.fullPath } }

  // The home page of each space.
  if (to.name === 'overview' && user.role !== 'employee') return homeFor(user.role)

  if (to.meta.roles && !to.meta.roles.includes(user.role)) return denied(user.role)

  const target = to.meta.userParam && to.params[to.meta.userParam]
  if (target && !isSelf(target)) {
    if (to.meta.selfOnly) return { ...to, params: { ...to.params, [to.meta.userParam]: String(user.id) } }
    // Managers see their teams, administrators everyone; the API refines it.
    if (!hasRole('manager', 'administrator')) return denied(user.role)
  }

  return true
})

export default router
