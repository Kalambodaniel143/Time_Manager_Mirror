import { fileURLToPath, URL } from 'node:url'
import process from 'node:process'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'
import { rewriteLocalOrigin } from './dev/apiProxy.js'

export default defineConfig(({ mode, command }) => {
  const env = loadEnv(mode, process.cwd(), '')
  if (command === 'build' && (env.VITE_USE_MOCK === 'true' || env.VITE_AUTH_USE_MOCK === 'true')) {
    throw new Error('Une version compilée ne peut pas activer les données simulées.')
  }
  if (command === 'build' && env.VITE_API_URL && env.VITE_API_URL !== '/api') {
    throw new Error('La version serveur utilise exclusivement /api sur la même origine.')
  }
  const backend = env.VITE_BACKEND_URL || 'http://localhost:4000'

  return {
    plugins: [
      vue(),
      ...(command === 'serve' ? [vueDevTools()] : []),
    ],

    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },

    server: {
      proxy: {
        '/api': {
          target: backend,
          changeOrigin: true,
          cookieDomainRewrite: '',
          configure(proxy) {
            proxy.on('proxyReq', (proxyRequest, request) => rewriteLocalOrigin(proxyRequest, request, backend))
          },
        },
      },
    },
  }
})
