<template>
  <div class="tour-backdrop" @click.self="$emit('close')">
    <section class="tour" role="dialog" aria-modal="true" aria-labelledby="tour-title">
      <p class="tour-step">Étape {{ index + 1 }} sur {{ steps.length }}</p>
      <h2 id="tour-title" class="tour-title">{{ step.title }}</h2>
      <p class="tour-text">{{ step.text }}</p>
      <footer class="tour-footer">
        <span class="tour-dots" aria-hidden="true">
          <span v-for="(item, dot) in steps" :key="item.title" class="tour-dot" :class="{ 'is-current': dot === index }"></span>
        </span>
        <button class="tour-later" type="button" @click="$emit('close')">Plus tard</button>
        <button ref="next" class="tour-next" type="button" @click="next">{{ isLast ? 'Terminer' : 'Suivant' }}</button>
      </footer>
    </section>
  </div>
</template>

<script>
export default {
  name: 'OnboardingTour',

  props: {
    steps: { type: Array, required: true },
  },

  emits: ['close'],

  data() {
    return { index: 0 }
  },

  computed: {
    step() {
      return this.steps[this.index]
    },

    isLast() {
      return this.index === this.steps.length - 1
    },
  },

  mounted() {
    this.$refs.next.focus()
    window.addEventListener('keydown', this.onKey)
  },

  beforeUnmount() {
    window.removeEventListener('keydown', this.onKey)
  },

  methods: {
    next() {
      if (this.isLast) this.$emit('close')
      else this.index += 1
    },

    onKey(event) {
      if (event.key === 'Escape') this.$emit('close')
    },
  },
}
</script>

<style scoped>
.tour-backdrop {
  position: fixed;
  inset: 0;
  z-index: 60;
  display: grid;
  place-items: center;
  padding: 16px;
  background: rgba(11, 16, 51, 0.55);
}

.tour {
  width: min(510px, 100%);
  padding: 26px 26px 24px;
  background: #0037ff;
  color: #ffffff;
  border-radius: 2px;
  box-shadow: var(--shadow-lg);
}

.tour-step {
  font-size: 13px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.tour-step::before {
  content: '< ';
  color: #3cf0b4;
  font-weight: 700;
}

.tour-step::after {
  content: ' />';
  color: #3cf0b4;
  font-weight: 700;
}

.tour-title {
  margin-top: 14px;
  font-size: 19px;
  font-weight: 700;
}

.tour-text {
  margin-top: 8px;
  font-size: 15.5px;
  line-height: 1.6;
}

.tour-footer {
  display: flex;
  align-items: center;
  gap: 24px;
  margin-top: 22px;
}

.tour-dots {
  display: flex;
  gap: 6px;
  margin-right: auto;
}

.tour-dot {
  width: 8px;
  height: 8px;
  background: rgba(255, 255, 255, 0.55);
}

.tour-dot.is-current {
  width: 24px;
  background: #ff5533;
}

.tour-later {
  padding: 0;
  background: none;
  border: none;
  color: #ffffff;
  font-weight: 700;
  text-decoration: underline;
  text-underline-offset: 3px;
}

.tour-next {
  padding: 10px 18px;
  background: #ffffff;
  border: none;
  border-radius: 2px;
  color: #0037ff;
  font-weight: 700;
}
</style>
