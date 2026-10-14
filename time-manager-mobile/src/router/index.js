import { createRouter, createWebHashHistory } from 'vue-router'
import MobileLayout from '@/layouts/MobileLayout.vue'
import LoginView from '@/views/LoginView.vue'
import TodayView from '@/views/TodayView.vue'
const HoursView = () => import('@/views/HoursView.vue')
const PlanningView = () => import('@/views/PlanningView.vue')
const AccountView = () => import('@/views/AccountView.vue')
const TeamView = () => import('@/views/TeamView.vue')
const TeamPlanningView = () => import('@/views/TeamPlanningView.vue')
const MemberView = () => import('@/views/MemberView.vue')
const OrgView = () => import('@/views/OrgView.vue')
const TeamsManageView = () => import('@/views/TeamsManageView.vue')
const MoreView = () => import('@/views/MoreView.vue')
const RequestsView = () => import('@/views/RequestsView.vue')
const NotificationsView = () => import('@/views/NotificationsView.vue')
const ReviewView = () => import('@/views/ReviewView.vue')
const WeeksView = () => import('@/views/WeeksView.vue')
const PayrollView = () => import('@/views/PayrollView.vue')
const RulesView = () => import('@/views/RulesView.vue')
const AuditView = () => import('@/views/AuditView.vue')
import { app } from '@/services/appState.js'
import { restoreSession } from '@/services/authService.js'
import { HOME_BY_ROLE } from '@/components/navigation/menu.js'

const MANAGERS = ['manager', 'administrator']
const ADMIN = ['administrator']

// Écrans chargés à la demande (plus léger au démarrage) ; connexion et pointage tout de suite.
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
        { path: 'plus', name: 'more', component: MoreView },
        { path: 'demandes', name: 'requests', component: RequestsView },
        { path: 'notifications', name: 'notifications', component: NotificationsView },
        { path: 'a-traiter', name: 'review', component: ReviewView, meta: { roles: MANAGERS } },
        { path: 'semaines', name: 'weeks', component: WeeksView, meta: { roles: MANAGERS } },
        { path: 'paie', name: 'payroll', component: PayrollView, meta: { roles: ADMIN } },
        { path: 'regles', name: 'rules', component: RulesView, meta: { roles: ADMIN } },
        { path: 'journal', name: 'audit', component: AuditView, meta: { roles: ADMIN } },
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
