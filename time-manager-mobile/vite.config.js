import { fileURLToPath, URL } from 'node:url'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'

// Le navigateur appelle /api ; Vite relaie vers le serveur de VITE_API_URL.
// Origin et Referer sont retirés : le serveur (plug CheckOrigin) refuse les
// écritures venant d'une autre adresse que la sienne.
// Même valeur par défaut que src/config/api.js.
const DEFAULT_SERVER_URL = 'http://34.155.104.175:8080/api'

function apiProxy(mode) {
  const target = new URL(loadEnv(mode, process.cwd(), 'VITE_').VITE_API_URL || DEFAULT_SERVER_URL).origin
  if (mode === 'development') console.log(`  ➜  API : /api est relayé vers ${target}`)
  return {
    '/api': {
      target,
      changeOrigin: true,
      configure: (proxy) => proxy.on('proxyReq', (req) => { req.removeHeader('origin'); req.removeHeader('referer') }),
    },
  }
}

export default defineConfig(({ mode }) => ({
  base: './',
  plugins: [
    vue(),
    {
      name: 'cordova-entry',
      // Cordova fournit ce script lors de la préparation de la plateforme.
      // L'aperçu navigateur n'en a pas besoin.
      transformIndexHtml: {
        order: 'post',
        handler: () => mode === 'cordova'
          ? [{ tag: 'script', attrs: { src: 'cordova.js' }, injectTo: 'head-prepend' }]
          : [],
      },
    },
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      '@shared': fileURLToPath(new URL('../shared', import.meta.url)),
    },
    dedupe: ['vue', 'vue-router'],
  },
  // chrome69 : la syntaxe récente (?., ??=…) est convertie pour les WebView d'Android 7+.
  build: { outDir: 'www', emptyOutDir: true, target: ['es2019', 'chrome69'] },
  server: {
    fs: { allow: [fileURLToPath(new URL('..', import.meta.url))] },
    proxy: apiProxy(mode),
  },
}))
