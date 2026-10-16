import './native/polyfills.js' // en premier : vieux téléphones
import { createApp } from 'vue'
import App from './App.vue'
import router from './router/index.js'
import { onBackButton, whenDeviceReady } from './native/lifecycle.js'
import { checkSession, restoreSession, watchOtherTabs } from './services/authService.js'
import { startAutoSync } from './services/syncService.js'
import { applyDisplay } from './ui/theme.js'
import { i18n } from './i18n/index.js'
import '@fontsource-variable/public-sans'
import './assets/main.css'

// Attendre les plugins natifs sur téléphone ; démarrer directement sur navigateur.
whenDeviceReady(() => {
  applyDisplay()
  if (restoreSession()) checkSession()
  watchOtherTabs()
  startAutoSync()
  // Retour Android : quitter depuis la connexion ou l'accueil, sinon page précédente
  // (la garde du routeur refuse les pages d'un autre compte).
  onBackButton(() => {
    if (['login', 'today'].includes(router.currentRoute.value.name)) navigator.app?.exitApp()
    else router.back()
  })
  createApp(App).use(router).use(i18n).mount('#app')
})
