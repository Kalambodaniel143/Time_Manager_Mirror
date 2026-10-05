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
  }
  return errors
}

export function organizationError(name) {
  const length = String(name || '').trim().length
  return length < 2 || length > 100 ? 'Le nom de l’organisation doit contenir entre 2 et 100 caractères.' : ''
}

export function passwordError(password) {
  return typeof password !== 'string' || password.length < 8 || password.length > 128 || !password.trim()
    ? 'Le mot de passe doit contenir entre 8 et 128 caractères.' : ''
}

export function errorFields(error) {
  const fields = error?.payload?.errors || {}
  return Object.fromEntries(Object.entries(fields).filter(([key]) => key !== 'detail').map(([key, value]) => [key, [].concat(value).join(' ')]))
}
