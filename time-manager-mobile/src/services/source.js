import { api as realApi } from './api.js'
import { workforceApi } from './workforceApi.js'

// Toutes les routes du serveur, réunies : les écrans importent « api » depuis ce fichier.
export const api = { ...realApi, ...workforceApi }
