import { createRouter, createWebHistory } from 'vue-router'
import ChartManager from '../components/ChartManager.vue'
import ClockManager from '../components/ClockManager.vue'
import WorkingTime from '../components/WorkingTime.vue'
import WorkingTimes from '../components/WorkingTimes.vue'
import { homeFor, readSession } from '../utils/session'
import EmployeePlanning from '../views/EmployeePlanning.vue'
import EmployeeToday from '../views/EmployeeToday.vue'
import PayrollMonth from '../views/PayrollMonth.vue'
import TeamOverview from '../views/TeamOverview.vue'
import TeamPlanning from '../views/TeamPlanning.vue'
import TeamsRights from '../views/TeamsRights.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/connexion',
      name: 'login',
      component: { render: () => null },
    },
    {
      path: '/',
      name: 'overview',
      component: EmployeeToday,
      meta: { role: 'employee' },
    },
    {
      path: '/planning',
      name: 'planning',
      component: EmployeePlanning,
      meta: { role: 'employee' },
    },
    {
      path: '/workingTimes/:userID',
      name: 'workingTimes',
      component: WorkingTimes,
      props: (route) => ({ userID: route.params.userID }),
      meta: { role: 'employee' },
    },
    {
      path: '/workingTime/:userid',
      name: 'workingTimeCreate',
      component: WorkingTime,
      props: (route) => ({ userId: route.params.userid, open: true }),
      meta: { role: 'employee' },
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
      meta: { role: 'employee' },
    },
    {
      path: '/clock/:userid',
      name: 'clock',
      component: ClockManager,
      props: (route) => ({ userId: route.params.userid }),
    },
    {
      path: '/chartManager/:userid',
      name: 'chartManager',
      component: ChartManager,
      props: (route) => ({ userId: route.params.userid }),
    },
    {
      path: '/equipe',
      name: 'team',
      component: TeamOverview,
      meta: { role: 'manager' },
    },
    {
      path: '/equipe/planning',
      name: 'teamPlanning',
      component: TeamPlanning,
      meta: { role: 'manager' },
    },
    {
      path: '/admin/paie',
      name: 'payroll',
      component: PayrollMonth,
      meta: { role: 'admin' },
    },
    {
      path: '/admin/droits',
      name: 'rights',
      component: TeamsRights,
      meta: { role: 'admin' },
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: { name: 'overview' },
    },
  ],
})

router.beforeEach((to) => {
  const session = readSession()

  if (!session) return to.name === 'login' ? true : { name: 'login' }
  if (to.name === 'login') return homeFor(session.role)
  if (to.meta.role && to.meta.role !== session.role) return homeFor(session.role)

  return true
})

export default router
