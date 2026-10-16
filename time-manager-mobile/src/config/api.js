// Serveur déployé du projet. VITE_API_URL dans .env.local le remplace si besoin.
export const DEFAULT_SERVER_URL = 'http://34.155.104.175:8080/api'
const SERVER_URL = import.meta.env.VITE_API_URL?.trim() || DEFAULT_SERVER_URL

// Téléphone : appel direct au serveur par le réseau natif.
// Navigateur en développement : /api, relayé par Vite vers SERVER_URL (même origine).
export const API_URL = window.cordova ? SERVER_URL : (import.meta.env.DEV ? '/api' : SERVER_URL)

// Comme le web (utils/gotham.js) : une seule organisation, retrouvée par son nom exact.
export const ORGANIZATION_NAME = import.meta.env.VITE_ORGANIZATION_NAME?.trim() || 'Gotham City'
