export const GOTHAM_NAME = 'Gotham City'

export function isGotham(organization) {
  return organization?.name?.trim().replace(/\s+/g, ' ').toLowerCase() === GOTHAM_NAME.toLowerCase()
}
