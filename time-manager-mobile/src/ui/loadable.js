// Mixin des écrans qui chargent des données : chargement, erreur, données anciennes.
// Utilisation : this.items = await this.run(() => getMesHeures())
export default {
  data: () => ({ loading: true, error: '', stale: false, updatedAt: null }),
  methods: {
    async run(task, { quiet = false } = {}) {
      if (!quiet) this.loading = true
      this.error = ''
      try {
        const result = await task()
        this.stale = result.stale
        this.updatedAt = result.updatedAt
        return result.data
      } catch (error) {
        this.error = error.message || 'Chargement impossible.'
        return null
      } finally {
        this.loading = false
      }
    },
  },
}
