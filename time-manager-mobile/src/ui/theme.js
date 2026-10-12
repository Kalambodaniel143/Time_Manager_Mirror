import { read, write } from '@/storage/database.js'

// Préférences d'affichage de « Mon compte » (thème + textes renforcés).
export const THEMES = [
  { value: 'light', label: 'Clair' },
  { value: 'night', label: 'Nuit' },
  { value: 'contrast', label: 'Contraste élevé' },
]

export const getDisplay = () => read('display', { theme: 'light', largeText: false })

export function applyDisplay(display = getDisplay()) {
  document.documentElement.dataset.theme = display.theme
  document.documentElement.dataset.text = display.largeText ? 'large' : 'normal'
  write('display', display)
}
