import { t } from '@/i18n/index.js'
// Fonctions natives (plugins Cordova), avec repli dans le navigateur.

// cordova-plugin-network-information : type de connexion du téléphone.
export function hasInternet() {
  const type = navigator.connection?.type
  if (type && window.Connection) return type !== window.Connection.NONE
  return navigator.onLine
}

// cordova-plugin-dialogs : vraie boîte de dialogue Android, sinon celle du navigateur.
export function confirmAction(message, button = 'Confirmer') {
  if (!navigator.notification?.confirm) return Promise.resolve(window.confirm(message))
  return new Promise((resolve) => {
    navigator.notification.confirm(message, (choice) => resolve(choice === 1), t('Time Manager'), [button, 'Annuler'])
  })
}

// cordova-plugin-vibration : petite vibration après un pointage.
export function vibrate(ms = 40) {
  navigator.vibrate?.(ms)
}
