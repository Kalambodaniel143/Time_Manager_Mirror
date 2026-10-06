// Un build installé doit avoir une adresse explicite, pas /api sur la WebView.
export const API_URL = import.meta.env.VITE_API_URL?.trim()
  || (import.meta.env.DEV ? '/api' : '')
