import { fieldMessage } from './apiErrors.js'

export const GENDERS = [
  { value: 'female', label: 'Femme' },
  { value: 'male', label: 'Homme' },
  { value: 'non_binary', label: 'Non binaire' },
  { value: 'unspecified', label: 'Je préfère ne pas préciser' },
]

export function emptyProfile() {
  return { first_name: '', last_name: '', email: '', gender: '', birth_date: '', birth_place: '' }
}

export function today() {
  const date = new Date()
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

export function latestAdultBirthDate(now = new Date()) {
  const year = now.getUTCFullYear() - 18
  const month = now.getUTCMonth()
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate()
  // A 29 February birthday falls on 28 February in a non-leap year, as on the API.
  const day = month === 1 && now.getUTCDate() === 28 && new Date(Date.UTC(now.getUTCFullYear(), 2, 0)).getUTCDate() === 28
    ? lastDay : Math.min(now.getUTCDate(), lastDay)
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

export function nameError(value) {
  return value && !/^[\p{L}\p{M} '\u2019-]+$/u.test(String(value))
    ? 'Utilisez des lettres, des espaces, des apostrophes ou des traits d’union, sans chiffres.' : ''
}

export function normalizeName(value) {
  return String(value || '').trim().replace(/\s+/g, ' ').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
}

export function profilePayload(profile, personalDetails = true) {
  const keys = personalDetails ? Object.keys(emptyProfile()) : ['first_name', 'last_name', 'email']
  return Object.fromEntries(keys.map((key) => [key, key === 'email' ? String(profile[key] || '').trim().toLowerCase() : String(profile[key] || '').trim()]))
}

export function profileErrors(profile, personalDetails = true) {
  const errors = {}
  const requiredNames = [['first_name', 'Le prénom'], ['last_name', 'Le nom']]
  if (personalDetails) requiredNames.push(['birth_place', 'Le lieu de naissance'])
  for (const [key, label] of requiredNames) {
    if (!String(profile[key] || '').trim()) errors[key] = `${label} est obligatoire.`
    else if (profile[key].trim().length > 100) errors[key] = '100 caractères au maximum.'
    else if (key !== 'birth_place' && nameError(profile[key])) errors[key] = nameError(profile[key])
  }
  const email = String(profile.email || '').trim()
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    errors.email = 'Saisissez une adresse email valide.'
  }
  if (!personalDetails) return errors
  if (!GENDERS.some((gender) => gender.value === profile.gender)) errors.gender = 'Choisissez une réponse.'
  const date = new Date(`${profile.birth_date}T00:00:00Z`)
  if (!/^\d{4}-\d{2}-\d{2}$/.test(profile.birth_date || '') || Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== profile.birth_date || profile.birth_date > today() || profile.birth_date < '1900-01-01') {
    errors.birth_date = 'Saisissez une date de naissance valide, entre 1900 et aujourd’hui.'
  } else if (profile.birth_date > latestAdultBirthDate()) {
    errors.birth_date = 'Vous devez avoir au moins 18 ans pour rejoindre l’organisation.'
  }
  return errors
}

export function organizationError(name) {
  const length = String(name || '').trim().length
  return length < 2 || length > 100 ? 'Le nom de l’organisation doit contenir entre 2 et 100 caractères.' : ''
}

export function passwordError(password) {
  if (typeof password !== 'string' || [...password].length < 8 || [...password].length > 128 || !password.trim()) return 'Le mot de passe doit contenir entre 8 et 128 caractères.'
  const normalized = password.toLowerCase().replace(/[^\p{L}\p{N}]/gu, '')
  const common = ['password', 'passwords', 'passw0rd', 'motdepasse', 'azerty', 'qwerty', 'letmein', 'welcome', 'bienvenue', 'admin', 'administrator', 'administrateur', 'gotham', 'gothamcity', 'changeme', 'abcdefgh', 'abcdefghij', 'abcdefghijklmnopqrstuvwxyz']
  if (/^\p{N}+$/u.test(normalized) || common.includes(normalized) || common.includes(normalized.replace(/\p{N}/gu, '')) || new Set([...normalized]).size < 4 || /^(.{1,4})\1+$/u.test(normalized)) {
    return 'Ce mot de passe est trop facile à deviner. Évitez les suites de chiffres, les répétitions et les mots courants. Choisissez une phrase de plusieurs mots personnels.'
  }
  return ''
}

export function errorFields(error) {
  const fields = error?.payload?.errors || {}
  return Object.fromEntries(Object.entries(fields).filter(([key]) => key !== 'detail' && key !== 'code').map(([key, value]) => [key, [].concat(value).map(message => fieldMessage(message, key)).join(' ')]))
}
