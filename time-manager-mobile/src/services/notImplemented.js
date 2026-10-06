// Un squelette doit échouer explicitement, jamais annoncer un faux succès.
export function notImplemented(feature) {
  const error = new Error(`${feature} : fonctionnalité à implémenter.`)
  error.code = 'NOT_IMPLEMENTED'
  throw error
}
