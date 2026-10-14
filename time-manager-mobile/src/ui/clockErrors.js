import { t } from '@/i18n/index.js'
// Motif lisible quand le serveur refuse un pointage (on garde son message d'origine).
const KNOWN = {
  'action is not allowed after the latest clock event': t('Impossible après votre dernier pointage enregistré (déjà pointé depuis un autre appareil ?)'),
  'must not precede the latest clock event': t('Heure antérieure à votre dernier pointage enregistré'),
  'must alternate arrivals and departures': t('Arrivées et départs doivent alterner'),
  'must record an arrival before a departure': t('Un départ doit suivre une arrivée'),
}

export function clockRefusal(error) {
  // « time Le pointage … futur. » -> « Le pointage … futur »
  const message = (error?.message ?? t('Refus du serveur')).replace(/^(time|status|kind|start|end)\s+/, '').replace(/\.$/, '')
  const known = Object.keys(KNOWN).find((text) => message.includes(text))
  return known ? KNOWN[known] : message
}

export const isFutureRefusal = (error) =>
  error?.kind === 'validation' && JSON.stringify(error.payload ?? '').includes('futur')
