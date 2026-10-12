// Phoenix checks the browser Origin against its Host. Vite changes Host when
// forwarding to a remote API; rewrite only requests from this Vite origin.
// Foreign origins must stay untouched so the backend can reject them.
export function rewriteLocalOrigin(proxyRequest, request, target) {
  const localOrigin = `http://${request.headers.host}`
  for (const header of ['origin', 'referer']) {
    const value = request.headers[header]
    if (typeof value !== 'string') continue
    try {
      const source = new URL(value)
      if (source.origin === localOrigin) {
        const destination = new URL(target)
        proxyRequest.setHeader(header, header === 'origin' ? destination.origin : new URL(source.pathname + source.search, destination).href)
      }
    } catch { /* Leave malformed headers for the backend to reject. */ }
  }
}
