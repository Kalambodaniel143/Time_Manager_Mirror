import { createRouter, createWebHistory } from 'vue-router'
import ChartManager from '../components/ChartManager.vue'
import ClockManager from '../components/ClockManager.vue'
import WorkingTime from '../components/WorkingTime.vue'
import WorkingTimes from '../components/WorkingTimes.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'overview',
    },
    {
      path: '/workingTimes/:userID',
      name: 'workingTimes',
      component: WorkingTimes,
      props: (route) => ({ userID: route.params.userID }),
    },
    {
      path: '/workingTime/:userid',
      name: 'workingTimeCreate',
      component: WorkingTime,
      props: (route) => ({ userId: route.params.userid, open: true }),
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
  ],
})

export default router
