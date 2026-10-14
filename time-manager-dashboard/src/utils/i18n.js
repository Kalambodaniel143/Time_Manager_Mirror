import { reactive } from 'vue'
import english from '../locales/en.json'

function storedLocale() { try { return globalThis.localStorage?.getItem('tm-language') === 'en' ? 'en' : 'fr' } catch { return 'fr' } }
export const language = reactive({ current: storedLocale() })
export function setLocale(value) {
  if (!['fr', 'en'].includes(value)) return
  language.current = value
  try { globalThis.localStorage?.setItem('tm-language', value) } catch { /* Storage can be disabled. */ }
  if (typeof document !== 'undefined') document.documentElement.lang = value
}
export const intlLocale = () => language.current === 'en' ? 'en-GB' : 'fr-FR'
const escapeRegex = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
// Existing computed labels include values. Match only known, complete messages;
// captured names, dates and user-authored content are preserved verbatim.
const patterns = Object.entries(english).filter(([key]) => /\{\w+\}/.test(key)).map(([key, value]) => {
  const names = [...key.matchAll(/\{(\w+)\}/g)].map(match => match[1])
  const pattern = key.split(/\{\w+\}/).map(escapeRegex).join('(.+?)')
  return { regex: new RegExp(`^${pattern}$`), names, value }
})
function translate(key, fallback) {
  if (Object.hasOwn(english, key)) return english[key]
  for (const { regex, names, value } of patterns) {
    const match = regex.exec(key)
    if (match) return value.replace(/\{(\w+)\}/g, (placeholder, name) => {
      const index = names.indexOf(name)
      return index < 0 ? placeholder : match[index + 1]
    })
  }
  if (key.includes(' · ')) return key.split(' · ').map(part => translate(part, part)).join(' · ')
  const colon = key.indexOf(' : ')
  if (colon > 0 && Object.hasOwn(english, key.slice(0, colon))) {
    return `${english[key.slice(0, colon)]}: ${translate(key.slice(colon + 3), key.slice(colon + 3))}`
  }
  return fallback
}
export function t(source, params = {}) {
  if (typeof source !== 'string') return source
  const key = source.replace(/\s+/g, ' ').trim()
  const result = language.current === 'en' ? translate(key, source) : source
  return result.replace(/\{(\w+)\}/g, (match, name) => Object.hasOwn(params, name) ? String(params[name]) : match)
}
export const i18n = { install(app) { app.config.globalProperties.$t = t; setLocale(language.current) } }
