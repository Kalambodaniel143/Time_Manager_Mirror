import { createRouter, createWebHashHistory } from 'vue-router'
import MobileLayout from '@/layouts/MobileLayout.vue'
import LoginView from '@/views/LoginView.vue'
import ClockView from '@/views/ClockView.vue'
import HoursView from '@/views/HoursView.vue'
import PlanningView from '@/views/PlanningView.vue'
import ProfileView from '@/views/ProfileView.vue'

// Le hash évite de dépendre d'une réécriture des URL par un serveur dans Cordova.
// Aperçu public sans données personnelles : Jonas ajoutera la garde de session.
export default createRouter({
  history: createWebHashHistory(),
  routes: [
    { path: '/connexion', name: 'login', component: LoginView },
    {
      path: '/',
      component: MobileLayout,
      children: [
        { path: '', redirect: { name: 'clock' } },
        { path: 'pointage', name: 'clock', component: ClockView, meta: { title: 'Pointage' } },
        { path: 'heures', name: 'hours', component: HoursView, meta: { title: 'Mes heures' } },
        { path: 'planning', name: 'planning', component: PlanningView, meta: { title: 'Planning' } },
        { path: 'profil', name: 'profile', component: ProfileView, meta: { title: 'Profil' } },
      ],
    },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
})
