import { notImplemented } from '@/services/notImplemented.js'

// Stockage protégé à brancher par Jonas ; PAS window.sessionStorage ni localStorage. Aucun mot de passe.
export async function readSession() { return notImplemented('Lecture de session protégée') }
export async function saveSession() { return notImplemented('Écriture de session protégée') }
export async function clearSession() { return notImplemented('Suppression de session protégée') }
