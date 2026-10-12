import { DATA_SOURCE } from '@/config/api.js'
import { api as realApi } from './api.js'
import { mockApi } from './mockApi.js'

// Choix de la source : VITE_DATA_SOURCE=api dans .env.local pour le vrai serveur.
export const api = DATA_SOURCE === 'api' ? realApi : mockApi
