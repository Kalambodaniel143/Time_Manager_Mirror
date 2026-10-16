import { read, write } from './database.js'

// Références des demandes d'adhésion faites sur ce téléphone (pour les suivre plus tard).
// La référence est privée : elle ne quitte le téléphone que vers le serveur.
export const listReferences = () => read('join-requests', [])

// Dernière demande : affichée à l'ouverture de « Rejoindre » (comme tm-last-join-receipt sur le web).
export const lastReference = () => listReferences()[0]?.reference ?? null
export const forgetReferences = () => write('join-requests', [])

export function saveReference(reference, organizationName) {
  const others = listReferences().filter((r) => r.reference !== reference)
  write('join-requests', [{ reference, organizationName, savedAt: new Date().toISOString() }, ...others])
}
