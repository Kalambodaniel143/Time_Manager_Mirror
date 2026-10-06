import { notImplemented } from './notImplemented.js'

// Jonas : getClockState() combine serveur et actions locales. recordClock(kind) confirme après écriture durable.
export async function getClockState() { return notImplemented('État du pointage') }
export async function recordClock() { return notImplemented('Enregistrement du pointage') }
