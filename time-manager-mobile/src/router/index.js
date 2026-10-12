import { createRouter, createWebHashHistory } from 'vue-router'
import MobileLayout from '@/layouts/MobileLayout.vue'
import LoginView from '@/views/LoginView.vue'
import TodayView from '@/views/TodayView.vue'
import HoursView from '@/views/HoursView.vue'
import PlanningView from '@/views/PlanningView.vue'
import AccountView from '@/views/AccountView.vue'
import TeamView from '@/views/TeamView.vue'
import TeamPlanningView from '@/views/TeamPlanningView.vue'
import MemberView from '@/views/MemberView.vue'
import OrgView from '@/views/OrgView.vue'
import TeamsManageView from '@/views/TeamsManageView.vue'
import { app } from '@/services/appState.js'
import { restoreSession } from '@/services/authService.js'
import { HOME_BY_ROLE } from '@/components/navigation/menu.js'

const MANAGERS = ['manager', 'administrator']
const ADMIN = ['administrator']

// Le hash évite de dépendre d'une réécriture des URL par un serveur dans Cordova.
// meta.roles : rôles autorisés (absent = tout compte connecté).
// Le serveur vérifie aussi chaque droit : ces règles servent au confort d'affichage.
const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    // Écrans sans session
    { path: '/connexion', name: 'login', component: LoginView, meta: { public: true } },
    // Comme le web : /inscription ouvre l'onglet « Rejoindre » de la connexion.
    { path: '/inscription', name: 'register', redirect: { name: 'login', query: { mode: 'join' } } },
    {
      path: '/',
      component: MobileLayout,
      children: [
        { path: '', name: 'home', redirect: () => ({ name: HOME_BY_ROLE[app.user?.role] ?? 'today' }) },
        { path: 'aujourdhui', name: 'today', component: TodayView },
        { path: 'heures', name: 'hours', component: HoursView },
        { path: 'planning', name: 'planning', component: PlanningView },
        { path: 'compte', name: 'account', component: AccountView },
        { path: 'equipe', name: 'team', component: TeamView, meta: { roles: MANAGERS } },
        { path: 'equipe/planning', name: 'teamPlanning', component: TeamPlanningView, meta: { roles: MANAGERS } },
        { path: 'agent/:id', name: 'member', component: MemberView, props: true, meta: { roles: MANAGERS } },
        { path: 'organisation', name: 'organization', component: OrgView, meta: { roles: ADMIN } },
        { path: 'comptes', name: 'users', redirect: { name: 'organization' } },
        { path: 'equipes/gestion', name: 'teamsManage', component: TeamsManageView, meta: { roles: ADMIN } },
      ],
    },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
})

router.beforeEach((to) => {
  restoreSession() // ne jamais se fier à un état resté en mémoire
  if (to.meta.public) return app.user ? { name: 'home' } : true
  if (!app.user) return { name: 'login' }
  if (to.meta.roles && !to.meta.roles.includes(app.user.role)) return { name: 'home' }
  return true
})

export default router
