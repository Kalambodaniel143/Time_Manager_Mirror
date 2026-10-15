<template>
  <ModalDialog v-if="step" :title="$t(step.title)" id="tour-title" @close="$emit('close')">
    <p class="tour-step">{{ $t("Prise en main · Étape") }} {{ index + 1 }} {{ $t("sur") }} {{ steps.length }}</p>
    <p class="tour-text">{{ $t(step.text) }}</p>
    <button v-if="supported" class="btn btn-outline" type="button" @click="read">{{ $t("Écouter cette étape") }}</button>
    <footer class="tour-footer">
      <span class="tour-dots" aria-hidden="true">
        <span v-for="(item, dot) in steps" :key="item.title" class="tour-dot" :class="{ 'is-current': dot === index }"></span>
      </span>
      <button class="btn btn-quiet tour-later" type="button" @click="$emit('close')">{{ $t("Plus tard") }}</button>
      <button class="btn btn-primary tour-next" type="button" @click="next">{{ $t(isLast ? 'Terminer' : 'Suivant') }}</button>
    </footer>
  </ModalDialog>
</template>

<script>
import ModalDialog from './ModalDialog.vue'
import { speechSupported, readAloud, stopReading } from '../../utils/speech'

export default {
  name: 'OnboardingTour',
  components: { ModalDialog },

  props: {
    steps: { type: Array, required: true },
  },

  emits: ['close'],

  data() {
    return { index: 0 }
  },

  beforeUnmount() { stopReading() },
  computed: {
    supported: speechSupported,
    step() {
      return this.steps[this.index]
    },

    isLast() {
      return this.index === this.steps.length - 1
    },
  },

  methods: {
    read() { readAloud(`${this.$t(this.step.title)}. ${this.$t(this.step.text)}`) },
    next() {
      stopReading()
      if (this.isLast) this.$emit('close')
      else this.index += 1
    },
  },
}
</script>

<style scoped>
.tour-step {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-muted);
}

.tour-text {
  font-size: 16px;
  line-height: 1.7;
  color: var(--text);
}

.tour-footer {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
  padding-top: 6px;
}

.tour-dots {
  display: flex;
  gap: 6px;
  margin-right: auto;
}

.tour-dot {
  width: 8px;
  height: 8px;
  background: var(--border-strong);
  border-radius: 999px;
}

.tour-dot.is-current {
  width: 24px;
  background: var(--brand);
}

@media (max-width: 400px) {
  .tour-dots {
    flex-basis: 100%;
  }

  .tour-later,
  .tour-next {
    flex: 1;
  }
}
</style>
