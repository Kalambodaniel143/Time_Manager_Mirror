export function whenDeviceReady(callback) {
  if (window.cordova) document.addEventListener('deviceready', callback, { once: true })
  else callback()
}

// Retour du réseau ou de l'application au premier plan : occasion de synchroniser.
// « online » n'est pas une preuve que l'API répond : la synchro le vérifiera.
export function onSyncOpportunity(callback) {
  for (const target of [window, document]) target.addEventListener('online', callback)
  document.addEventListener('resume', callback)
}

// Bouton retour physique d'Android.
export function onBackButton(callback) {
  document.addEventListener('backbutton', callback)
}

export function onConnectionLost(callback) {
  for (const target of [window, document]) target.addEventListener('offline', callback)
}
