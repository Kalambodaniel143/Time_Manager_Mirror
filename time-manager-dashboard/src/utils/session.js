export const THEMES = ['light', 'night', 'contrast']

const THEME_KEY = 'tm-theme'

const THEME_COLORS = { light: '#24584f', night: '#121b17', contrast: '#123c2e' }

export function readStorage(key) {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}

export function writeStorage(key, value) {
  try {
    if (value === null) localStorage.removeItem(key)
    else localStorage.setItem(key, value)
  } catch {
    return
  }
}

export function readJson(key, fallback) {
  try {
    const raw = readStorage(key)
    return raw ? JSON.parse(raw) : fallback
  } catch {
    return fallback
  }
}

export function writeJson(key, value) {
  writeStorage(key, value === null ? null : JSON.stringify(value))
}

export function readTheme() {
  const theme = readStorage(THEME_KEY)
  return THEMES.includes(theme) ? theme : 'light'
}

export function writeTheme(theme) {
  writeStorage(THEME_KEY, theme)
}

export function applyTheme(theme) {
  if (typeof document === 'undefined') return

  document.documentElement.setAttribute('data-theme', theme)
  const meta = document.querySelector('meta[name="theme-color"]')
  if (meta) meta.setAttribute('content', THEME_COLORS[theme] || THEME_COLORS.light)
}

export const ROLE_HOME = { employee: 'overview', manager: 'team', administrator: 'payroll' }

export function homeFor(role) {
  return { name: ROLE_HOME[role] || ROLE_HOME.employee }
}

export function readStrongText() { return readStorage('tm-strong-text') === 'true' }
export function applyStrongText(value) {
  if (typeof document !== 'undefined') document.documentElement.dataset.strongText = String(Boolean(value))
}
export function writeStrongText(value) { writeStorage('tm-strong-text', String(Boolean(value))); applyStrongText(value) }
