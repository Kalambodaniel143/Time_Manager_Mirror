<template>
  <div class="page-stack">
    <PageHeader :title="$t(&quot;Notifications&quot;)"><button class="btn btn-outline" :disabled="loading" @click="load">{{ $t("Actualiser") }}</button></PageHeader>
    <div class="filters"><label class="field"><span class="field-label">{{ $t("Afficher") }}</span><select v-model="filter" class="input" @change="page = 1; load()"><option value="all">{{ $t("Toutes") }}</option><option value="unread">{{ $t("Non lues") }}</option><option value="read">{{ $t("Lues") }}</option></select></label><p role="status">{{ unreadCount }} {{ $t("notification(s) non lue(s)") }}</p></div>
    <p v-if="error" class="field-error" role="alert">{{ $t(error) }}</p>
    <p v-if="loading" role="status">{{ $t("Chargement…") }}</p>
    <section v-else-if="!error" class="card section-card page-stack">
      <p v-if="!items.length" class="muted">{{ $t("Aucune notification pour ce filtre.") }}</p>
      <article v-for="item in items" :key="item.id" class="notification" :class="{ unread: !item.read_at }">
        <div><h2 class="card-title"><span v-if="!item.read_at" class="unread-dot" aria-hidden="true"></span>{{ $t(item.title) }}</h2><p>{{ $t(item.body) }}</p><time class="field-hint" :datetime="item.inserted_at">{{ formatDate(item.inserted_at) }}</time><span v-if="!item.read_at" class="pill pill-warn">{{ $t("Non lue") }}</span></div>
        <button v-if="!item.read_at" class="btn btn-outline btn-sm" :disabled="marking !== null" @click="mark(item)">{{ $t(marking === item.id ? 'Enregistrement…' : 'Marquer comme lue') }}</button><span v-else class="pill pill-ok">{{ $t("Lue") }}</span>
      </article>
      <div class="pagination"><button class="btn btn-outline" :disabled="page <= 1" @click="page -= 1; load()">{{ $t("Précédent") }}</button><span>{{ $t("Page") }} {{ page }}</span><button class="btn btn-outline" :disabled="items.length < 50" @click="page += 1; load()">{{ $t("Suivant") }}</button></div>
    </section>
  </div>
</template>
<script>
import { intlLocale } from '../utils/i18n.js'

import PageHeader from '../components/ui/PageHeader.vue'
import { workforce, listNotifications, readNotification, refreshNotificationCount } from '../services/workforceService'
export default {
  name: 'Notifications', components: { PageHeader },
  data() { return { items: [], loading: false, error: '', version: 0, filter: 'all', page: 1, marking: null } },
  computed: { unreadCount() { return workforce.unreadCount } },
  created() { this.load() }, beforeUnmount() { this.version += 1 },
  methods: {
    formatDate(value) { return new Intl.DateTimeFormat(intlLocale(), { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) },
    async load() {
      const version = ++this.version; this.loading = true; this.error = ''
      try { const [items] = await Promise.all([listNotifications(this.filter, this.page), refreshNotificationCount()]); if (version === this.version) this.items = items }
      catch (error) { if (version === this.version) this.error = error.message }
      finally { if (version === this.version) this.loading = false }
    },
    async mark(item) {
      if (this.marking) return
      this.marking = item.id
      try { await readNotification(item.id); await this.load() }
      catch (error) { this.error = error.message }
      finally { this.marking = null }
    },
  },
}
</script>
<style scoped>
.notification { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 18px; align-items: center; border-bottom: 1px solid var(--border); padding: 16px; overflow-wrap: anywhere; }
.notification p { margin: 10px 0; }
.unread { border-left: 4px solid var(--brand); background: var(--brand-soft); }
.unread-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: var(--brand); margin-right: 8px; }
.filters, .pagination { display: flex; gap: 16px; justify-content: space-between; align-items: center; flex-wrap: wrap; }
.notification time { display: inline-block; margin-right: 12px; }
@media (max-width: 760px) { .notification { grid-template-columns: 1fr; } }
</style>
