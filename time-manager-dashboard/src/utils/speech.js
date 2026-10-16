import { intlLocale } from './i18n.js'
import { reactive } from 'vue'
import { workforce } from '../services/workforceService'
let generation = 0
export const speech = reactive({ speaking: false, error: '' })
export function speechSupported() { return typeof window !== 'undefined' && Boolean(window.speechSynthesis && window.SpeechSynthesisUtterance) }
export function stopReading() { generation += 1; if (speechSupported()) window.speechSynthesis.cancel(); speech.speaking = false }
export function readAloud(text, overrides = {}) {
  if (!speechSupported()) { speech.error = 'La lecture vocale n’est pas disponible dans ce navigateur.'; return }
  stopReading(); speech.error = ''
  const current = generation
  const preferences = { ...workforce.preferences, ...overrides }
  const utterance = new window.SpeechSynthesisUtterance(String(text).trim())
  utterance.lang = intlLocale(); utterance.rate = preferences.speech_rate || 1
  utterance.voice = window.speechSynthesis.getVoices().find(voice => voice.name === preferences.speech_voice) || null
  utterance.onstart = () => { if (current === generation) speech.speaking = true }
  utterance.onend = () => { if (current === generation) speech.speaking = false }
  utterance.onerror = event => { if (current !== generation) return; speech.speaking = false; if (!['canceled','interrupted'].includes(event.error)) speech.error = 'La lecture n’a pas pu être terminée.' }
  window.speechSynthesis.speak(utterance)
}
