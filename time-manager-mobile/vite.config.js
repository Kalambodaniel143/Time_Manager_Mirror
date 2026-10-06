import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

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
  build: { outDir: 'www', emptyOutDir: true },
  server: {
    fs: { allow: [fileURLToPath(new URL('..', import.meta.url))] },
    proxy: { '/api': { target: 'http://localhost:4000', changeOrigin: true } },
  },
}))
