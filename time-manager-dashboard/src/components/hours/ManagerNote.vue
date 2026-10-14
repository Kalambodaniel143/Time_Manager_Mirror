<template>
  <section class="note card">
    <label class="note-title" for="manager-note">{{ $t("Note pour votre manager") }}</label>
    <p class="note-hint">{{ $t("Facultatif. Pour expliquer une journée particulière.") }}</p>
    <textarea id="manager-note" v-model="text" :disabled="loading || (!demo && (!ownNote || weekStatus !== 'open'))" class="input note-input" rows="3" @change="save"></textarea>
    <p class="note-visible"><AppIcon name="eye" />{{ $t(demo ? 'Note enregistrée dans ce navigateur.' : 'Note partagée avec votre responsable.') }}</p>
    <p v-if="error" class="field-error" role="alert">{{ $t(error) }}</p>
    <p class="note-hint">{{ $t("Une note est facultative et ne remplace pas une demande de correction.") }}</p>
  </section>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import { auth } from '../../stores/auth'
import { isDemoData } from '../../services/orgService'
import { getNote, saveNote } from '../../services/workforceService'
import { noteFor, setNote } from '../../services/orgService'

export default {
  name: 'ManagerNote',

  components: { AppIcon },

  props: {
    userId: { type: Number, default: null },
    username: { type: String, default: '' },
    weekKey: { type: String, required: true },
  },

  data() {
    return { text: '', error: '', loading: false, version: 0, weekStatus: 'open' }
  },

  computed: { demo: isDemoData, ownNote() { return auth.user?.id === this.userId } },
  beforeUnmount() { this.version += 1 },
  watch: {
    weekKey: {
      immediate: true,
      handler() {
        this.load()
      },
    },
  },

  methods: {
    async load() {
      const version = ++this.version; this.error = ''
      if (this.demo) { this.text = noteFor(this.username, this.weekKey); return }
      this.loading = true
      try { const row = await getNote(this.userId, this.weekKey); if (version === this.version) { this.text = row.note; this.weekStatus = row.status } }
      catch (error) { if (version === this.version) this.error = error.message }
      finally { if (version === this.version) this.loading = false }
    },
    async save() {
      if (this.demo) { setNote(this.username, this.weekKey, this.text.trim()); return }
      if (!this.ownNote) return
      this.error = ''
      try { await saveNote(this.userId, this.weekKey, this.text.trim()) }
      catch (error) { this.error = error.message }
    },
  },
}
</script>

<style scoped>
.note {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 24px;
}

.note-title {
  font-size: 16px;
  font-weight: 700;
}

.note-hint {
  font-size: 14px;
  color: var(--text-muted);
}

.note-input {
  margin-top: 6px;
  font-size: 16px;
  line-height: 1.6;
  resize: vertical;
}

.note-visible {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: var(--text-muted);
}

.note-visible svg {
  width: 16px;
  height: 16px;
}
</style>
