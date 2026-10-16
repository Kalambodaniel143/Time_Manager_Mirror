import { t } from '@/i18n/index.js'
// Messages des écrans publics à partir des erreurs de l'API.
const BY_KIND = {
  unauthorized: t('Adresse e-mail ou mot de passe incorrect.'),
  network: t('Serveur injoignable. Vérifiez votre connexion puis réessayez.'),
  timeout: t('Le serveur ne répond pas. Réessayez dans un instant.'),
  server: t('Le serveur rencontre une erreur. Réessayez plus tard.'),
  forbidden: t('Le serveur a refusé la demande.'),
}

export function authError(error) {
  // 502/503/504 : le relais (Vite, Nginx) n'atteint pas le serveur.
  if ([502, 503, 504].includes(error?.status)) return t('Serveur injoignable : vérifiez l’adresse du serveur (VITE_API_URL) et qu’il est démarré.')
  if (error?.status === 429) return t('Trop de tentatives. Patientez une minute avant de réessayer.')
  // 404 / 409 / 422 : le serveur fournit un message lisible (errors.detail ou champs).
  if ([404, 409, 422].includes(error?.status)) return error.message
  const text = BY_KIND[error?.kind] ?? error?.message ?? t('Une erreur est survenue.')
  return error?.detail ? `${text} (${error.detail})` : text
}

export const PASSWORD_RULE = t('De 8 à 128 caractères.')
export const validPassword = (value) => value.length >= 8 && value.length <= 128 && value.trim() !== ''
