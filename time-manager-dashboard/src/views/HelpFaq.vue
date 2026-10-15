<template>
  <component :is="standalone ? 'main' : 'section'" :id="standalone ? 'main-content' : undefined" class="faq" :class="{ 'faq-public': standalone }">
    <div v-if="standalone" class="faq-controls">
      <RouterLink class="btn btn-outline" :to="{ name: 'login' }">{{ $t('Retour à la connexion') }}</RouterLink>
      <LanguageSelect />
      <ThemeToggle :model-value="theme" @update:model-value="$emit('update:theme', $event)" />
    </div>
    <PageHeader :title="$t('Aide et FAQ')" :eyebrow="$t('Time Manager')" />
    <p class="faq-intro">{{ $t('Comprendre Time Manager, protéger vos données et savoir où demander de l’aide.') }}</p>
    <nav class="faq-topics" :aria-label="$t('Rubriques de la FAQ')">
      <a v-for="group in groups" :key="group.id" class="btn btn-outline btn-sm" :href="`#faq-${group.id}`">{{ $t(group.title) }}</a>
    </nav>
    <section v-for="group in groups" :key="group.id" :aria-labelledby="`faq-${group.id}`" class="faq-group">
      <h2 :id="`faq-${group.id}`">{{ $t(group.title) }}</h2>
      <details v-for="item in group.items" :key="item.id" class="card faq-item">
        <summary>{{ $t(item.question) }}</summary>
        <p>{{ $t(item.answer) }}</p>
      </details>
    </section>
    <aside class="card faq-support">
      <h2>{{ $t('Une question reste sans réponse ?') }}</h2>
      <p>{{ $t('Contactez votre responsable pour les horaires, les RH pour les règles de travail et votre administrateur pour les accès ou les erreurs techniques.') }}</p>
    </aside>
  </component>
</template>

<script>
import { RouterLink } from 'vue-router'
import PageHeader from '../components/ui/PageHeader.vue'
import LanguageSelect from '../components/ui/LanguageSelect.vue'
import ThemeToggle from '../components/ui/ThemeToggle.vue'
import groups from '../content/faq.json'

export default {
  name: 'HelpFaq',
  components: { RouterLink, PageHeader, LanguageSelect, ThemeToggle },
  props: { standalone: Boolean, theme: { type: String, default: 'light' } },
  emits: ['update:theme'],
  data() { return { groups } },
}
</script>

<style scoped>
.faq { max-width: 960px; margin: 0 auto; }
.faq-public { padding: 32px 24px 60px; }
.faq-controls, .faq-topics { display: flex; flex-wrap: wrap; align-items: center; gap: 12px; margin-bottom: 28px; }
.faq-controls > :first-child { margin-right: auto; }
.faq-intro { color: var(--text-muted); line-height: 1.6; margin-bottom: 24px; }
.faq-group { margin-bottom: 32px; }
.faq h2 { color: var(--title); font-size: 20px; margin-bottom: 16px; scroll-margin-top: 24px; }
.faq-item { margin-bottom: 12px; }
.faq-item summary { padding: 18px 20px; cursor: pointer; font-weight: 600; color: var(--title); }
.faq-item summary:focus-visible { outline: 3px solid var(--brand); outline-offset: 3px; border-radius: var(--radius-sm); }
.faq-item p { padding: 0 20px 20px; margin: 0; line-height: 1.7; overflow-wrap: anywhere; }
.faq-support { padding: 24px; line-height: 1.7; }
@media (max-width: 600px) { .faq-public { padding: 20px 16px 40px; } }
</style>
