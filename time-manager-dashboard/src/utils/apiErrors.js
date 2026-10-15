const labels = {
  email: 'Adresse email', username: 'Identifiant', password: 'Mot de passe', current_password: 'Mot de passe actuel',
  first_name: 'Prénom', last_name: 'Nom', birth_date: 'Date de naissance', birth_place: 'Lieu de naissance', gender: 'Genre',
  name: 'Nom', role: 'Rôle', manager_id: 'Manager', user_id: 'Utilisateur', organization_id: 'Organisation',
  start: 'Début', end: 'Fin', week: 'Semaine', reason: 'Motif', note: 'Note', status: 'Statut',
  hourly_rate: 'Taux horaire', payable_hours: 'Heures rémunérées', revision: 'Version du planning', code: 'Code de vérification',
}
const messages = {
  'must be after start': 'La fin doit être postérieure au début. Vérifiez les dates et les heures de la période.',
  'must not precede the latest clock event': 'Cette heure précède le dernier pointage enregistré. Choisissez une heure ultérieure.',
  'action is not allowed after the latest clock event': 'Ce pointage ne peut pas suivre le précédent. Actualisez la page : une arrivée doit être suivie d’un départ, et inversement.',
  "can't be blank": 'Ce champ est obligatoire.',
  'is invalid': 'La valeur saisie n’est pas valide. Vérifiez le format demandé.',
  'is not valid': 'La valeur saisie est incorrecte. Vérifiez votre saisie.',
  'has already been taken': 'Cette valeur est déjà utilisée. Choisissez-en une autre.',
  'must look like name@domain.tld': 'Saisissez une adresse email valide, par exemple nom@domaine.fr.',
  'does not exist': 'Cette sélection n’existe plus. Actualisez la liste et choisissez une autre valeur.',
  'must have the manager role': 'Choisissez une personne qui possède le rôle manager ou administrateur.',
  'Invalid credentials': 'Connexion impossible : l’adresse email ou le mot de passe est incorrect. Vérifiez les deux champs ou utilisez « Mot de passe oublié ». Un compte en attente d’acceptation ne peut pas encore se connecter.',
  'The last administrator cannot be demoted or deleted': 'Le dernier super administrateur ne peut pas être supprimé ni changer de rôle. Transférez d’abord ses responsabilités.',
  'Invalid verification code': 'Le code de vérification est incorrect. Recopiez le dernier code reçu par email.',
  'Verification code expired': 'Le code de vérification a expiré. Demandez un nouveau code.',
  'Too many verification attempts': 'Trop de codes incorrects ont été saisis. Demandez un nouveau code avant de réessayer.',
  'Email delivery is unavailable': 'Le service email est indisponible. Réessayez plus tard ou contactez l’administrateur.',
}
export function fieldMessage(message, field) {
  if (field === 'current_password' && message === 'is not valid') return 'Le mot de passe actuel est incorrect. Saisissez celui que vous utilisez pour vous connecter.'
  if (messages[message]) return messages[message]
  const length = /^should be (at least|at most) (\d+) character\(s\)$/.exec(message)
  if (length) return `${length[1] === 'at least' ? 'Saisissez au moins' : 'Limitez la saisie à'} ${length[2]} caractères${length[1] === 'at most' ? ' au maximum' : ''}.`
  return String(message)
}
export function apiErrorMessage(status, payload) {
  const defaults = {
    0: 'Impossible de joindre le serveur. Vérifiez votre connexion internet puis réessayez. Si le problème persiste, contactez l’administrateur.',
    400: 'La demande est incomplète ou mal formée. Vérifiez les champs du formulaire puis réessayez.',
    401: 'Votre session a expiré ou n’est plus valide. Reconnectez-vous pour continuer.',
    403: 'Vous n’avez pas les droits nécessaires pour cette action. Contactez votre administrateur si cet accès est nécessaire.',
    404: 'L’élément demandé est introuvable ou n’est pas accessible à votre compte. Actualisez la page et vérifiez votre sélection.',
    409: 'Cette action entre en conflit avec une modification déjà enregistrée. Actualisez les données avant de réessayer.',
    422: 'Certaines informations sont invalides. Vérifiez les champs indiqués et corrigez votre saisie.',
    429: 'Trop de tentatives rapprochées. Patientez une minute avant de réessayer.',
    500: 'Le serveur n’a pas pu terminer cette action. Actualisez pour vérifier si elle a été enregistrée avant de la relancer. Si le problème persiste, contactez l’administrateur.',
    502: 'Le service est momentanément injoignable. Réessayez dans quelques instants ; si le problème persiste, contactez l’administrateur.',
    503: 'Le service est temporairement indisponible. Réessayez plus tard ou contactez l’administrateur.',
    504: 'Le serveur a mis trop de temps à répondre. Actualisez pour vérifier le résultat avant de réessayer.',
  }
  const errors = payload?.errors
  const parts = []
  if (errors && typeof errors === 'object' && status < 500) {
    if (typeof errors.detail === 'string' && !['Unauthorized', 'Forbidden', 'Not Found', 'Bad Request'].includes(errors.detail)) parts.push(fieldMessage(errors.detail))
    for (const [key, values] of Object.entries(errors)) {
      if (key === 'detail' || key === 'code') continue
      const strings = [values].flat().filter(value => typeof value === 'string')
      if (strings.length) parts.push(`${labels[key] || 'Champ à vérifier'} : ${strings.map(value => fieldMessage(value, key)).join(' ')}`)
    }
  }
  if (status === 503 && errors?.detail === 'Email delivery is unavailable') return messages[errors.detail]
  return parts.join(' · ') || defaults[status] || `Cette action n’a pas abouti (code ${status}). Réessayez ou communiquez ce code à l’administrateur.`
}
