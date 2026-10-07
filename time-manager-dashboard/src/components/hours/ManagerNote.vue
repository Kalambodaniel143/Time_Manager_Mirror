<template>
  <section class="note card">
    <label class="note-title" for="manager-note">Note pour votre manager</label>
    <p class="note-hint">Facultatif. Pour expliquer une journée particulière.</p>
    <textarea id="manager-note" v-model="text" class="input note-input" rows="3" @change="save"></textarea>
    <p class="note-visible"><AppIcon name="eye" />Note enregistrée dans ce navigateur · le partage avec votre responsable reste à raccorder.</p>
    <p class="note-hint">Une note est facultative et ne remplace pas une demande de correction.</p>
  </section>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import { TEAM } from '../../mocks/org'
import { noteFor, setNote } from '../../services/orgService'

export default {
  name: 'ManagerNote',

  components: { AppIcon },

  props: {
    username: { type: String, required: true },
    weekKey: { type: String, required: true },
  },

  data() {
    return { text: '', managerName: TEAM.manager.short }
  },

  watch: {
    weekKey: {
      immediate: true,
      handler() {
        this.text = noteFor(this.username, this.weekKey)
      },
    },
  },

  methods: {
    save() {
      setNote(this.username, this.weekKey, this.text.trim())
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
