const users = [
  { id: 1, username: 'bruce.wayne', email: 'bruce.wayne@gotham.gov' },
  { id: 2, username: 'selina.kyle', email: 'selina.kyle@gotham.gov' },
  { id: 3, username: 'lucius.fox', email: 'lucius.fox@gotham.gov' },
  { id: 4, username: 'barbara.gordon', email: 'barbara.gordon@gotham.gov' },
  { id: 5, username: 'alfred.pennyworth', email: 'alfred.pennyworth@gotham.gov' },
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
