<template>
  <div class="language-control">
    <label><span class="sr-only">{{ $t('Langue') }}</span><select :value="language.current" :aria-label="$t('Langue')" :disabled="saving" @change="change($event.target.value)"><option value="fr">Français</option><option value="en">English</option></select></label>
    <span v-if="error" class="field-error" role="alert">{{ $t(error) }}</span>
  </div>
</template>
<script>
import { language, setLocale } from '../../utils/i18n'
import { auth } from '../../stores/auth'
import { savePreferences } from '../../services/workforceService'
import { stopReading } from '../../utils/speech'
export default {
  name: 'LanguageSelect', data() { return { language, saving: false, error: '' } },
  methods: { async change(value) { stopReading(); setLocale(value); this.error = ''; if (!auth.user || auth.organizationSession) return; this.saving = true; try { await savePreferences({ language: value }) } catch (error) { this.error = error.message } finally { this.saving = false } } },
}
</script>
<style scoped>
.language-control { display: inline-flex; flex-direction: column; gap: 4px; max-width: 100%; }
select { border: 1px solid var(--border); background: var(--surface); color: var(--text); border-radius: 6px; padding: 8px 10px; font: inherit; }
</style>
