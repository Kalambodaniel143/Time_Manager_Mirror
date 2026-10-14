import { reactive } from 'vue'
import en from './en.js'

// Langue de l'application : français (textes du code) ou anglais (dictionnaire en.js).
// La clé de traduction EST le texte français : t('Mes heures') -> « My hours » en anglais.
// Paramètres : t('Bonjour {0}', [prénom]) ou t('{n} agents', { n: 3 }).
const KEY = 'tm:lang'
const saved = (() => { try { return localStorage.getItem(KEY) } catch { return null } })()
export const lang = reactive({ value: saved === 'en' || saved === 'fr' ? saved : 'fr' })

export function t(key, args) {
  const text = lang.value === 'en' ? (en[key] ?? key) : key
  if (!args) return text
  return text.replace(/\{(\w+)\}/g, (match, name) => (args[name] ?? match))
}

// Locale des dates et nombres (Intl).
export const locale = () => (lang.value === 'en' ? 'en-GB' : 'fr-FR')

export function setLang(value) {
  lang.value = value
  document.documentElement.lang = value
  try { localStorage.setItem(KEY, value) } catch { /* stockage indisponible : langue gardée pour la session */ }
}

// Plugin Vue : $t et $lang dans tous les gabarits.
export const i18n = {
  install(app) {
    app.config.globalProperties.$t = t
    app.config.globalProperties.$lang = lang
    document.documentElement.lang = lang.value
  },
}
