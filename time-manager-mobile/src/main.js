import { createApp } from 'vue'
import App from './App.vue'
import router from './router/index.js'
import { whenDeviceReady } from './native/lifecycle.js'
import './assets/main.css'

// Attendre les plugins natifs sur téléphone ; démarrer directement sur navigateur.
whenDeviceReady(() => createApp(App).use(router).mount('#app'))
