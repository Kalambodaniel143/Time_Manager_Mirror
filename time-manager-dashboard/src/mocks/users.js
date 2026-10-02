const users = [
  { id: 1, username: 'marie.dubois', email: 'marie.dubois@gotham.gov' },
  { id: 2, username: 'lucie.ferreira', email: 'lucie.ferreira@gotham.gov' },
  { id: 3, username: 'albert.r', email: 'albert.r@gotham.gov' },
  { id: 4, username: 'karim.benali', email: 'karim.benali@gotham.gov' },
  { id: 5, username: 'sara.ortiz', email: 'sara.ortiz@gotham.gov' },
  { id: 6, username: 'john.doe', email: 'john.doe@gotham.gov' },
  { id: 7, username: 'hugo.lin', email: 'hugo.lin@gotham.gov' },
  { id: 8, username: 'paula.ibanez', email: 'paula.ibanez@gotham.gov' },
]

function copy(user) {
  return user ? { ...user } : null
}

export function mockListUsers(filters = {}) {
  return users
    .filter((user) => {
      if (filters.email && user.email !== filters.email) return false
      if (filters.username && user.username !== filters.username) return false
      return true
    })
    .map(copy)
}

export function mockGetUser(id) {
  return copy(users.find((user) => user.id === Number(id)))
}

export function mockCreateUser(attrs) {
  const created = {
    id: Math.max(0, ...users.map((user) => user.id)) + 1,
    username: attrs.username,
    email: attrs.email,
  }

  users.push(created)
  return copy(created)
}

export function mockUpdateUser(id, attrs) {
  const user = users.find((item) => item.id === Number(id))
  if (!user) return null

  Object.assign(user, attrs)
  return copy(user)
}

export function mockDeleteUser(id) {
  const index = users.findIndex((user) => user.id === Number(id))
  if (index === -1) return null

  return copy(users.splice(index, 1)[0])
}
