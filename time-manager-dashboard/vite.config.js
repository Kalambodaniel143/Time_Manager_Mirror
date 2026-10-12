import { fileURLToPath, URL } from 'node:url'
import process from 'node:process'
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'
import { rewriteLocalOrigin } from './dev/apiProxy.js'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const backend = env.VITE_BACKEND_URL || 'http://localhost:4000'

  return {
    plugins: [
      vue(),
      vueDevTools(),
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
