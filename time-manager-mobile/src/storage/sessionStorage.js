import { read, write, remove } from './database.js'

// Session = utilisateur + jeton CSRF renvoyé par /auth/login.
// Le JWT reste dans le cookie HttpOnly ; le mot de passe n'est JAMAIS stocké.
export const readSession = () => read('session')
export const saveSession = (session) => write('session', session)
export const clearSession = () => remove('session')
