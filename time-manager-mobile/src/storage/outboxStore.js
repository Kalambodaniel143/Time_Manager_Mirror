import { notImplemented } from '@/services/notImplemented.js'

// Jonas : conserver identifiant unique, compte, heure d'origine, ordre et état.
export async function enqueueAction() { return notImplemented('Mise en attente') }
export async function listPendingActions() { return notImplemented('Lecture des actions en attente') }
export async function markConfirmed() { return notImplemented('Confirmation serveur') }
