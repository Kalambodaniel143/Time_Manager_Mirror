export function whenDeviceReady(callback) {
  if (window.cordova) document.addEventListener('deviceready', callback, { once: true })
  else callback()
}

// À brancher après initialisation de la session et de la base.
// online est une occasion de réessayer, pas une preuve que l'API est accessible.
export function onSyncOpportunity(callback) {
  window.addEventListener('online', callback)
  document.addEventListener('resume', callback)
  return () => {
    window.removeEventListener('online', callback)
    document.removeEventListener('resume', callback)
  }
}
