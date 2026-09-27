<template>
  <div class="toast-stack" aria-live="polite">
    <TransitionGroup name="toast">
      <div v-for="toast in toasts" :key="toast.id" class="toast" :class="`toast-${toast.tone}`">
        <span class="toast-icon" aria-hidden="true">
          <svg v-if="toast.tone === 'error'" viewBox="0 0 16 16">
            <path d="M8 4.5v4M8 11h.01" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" />
          </svg>
          <svg v-else viewBox="0 0 16 16">
            <path d="M4 8.5l2.5 2.5L12 5.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </span>
        <span class="toast-message">{{ toast.message }}</span>
        <button class="toast-close" type="button" aria-label="Fermer" @click="close(toast.id)">
          <svg viewBox="0 0 16 16" aria-hidden="true">
            <path d="M4.5 4.5l7 7M11.5 4.5l-7 7" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
          </svg>
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>

<script>
import { dismiss, toasts } from '../utils/toast'

export default {
  name: 'ToastStack',

  data() {
    return { toasts }
  },

  methods: {
    close(id) {
      dismiss(id)
    },
  },
}
</script>

<style scoped>
.toast-stack {
  position: fixed;
  right: 20px;
  bottom: 20px;
  z-index: 80;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 10px;
  pointer-events: none;
}

.toast {
  display: flex;
  align-items: center;
  gap: 10px;
  max-width: 380px;
  padding: 11px 12px 11px 14px;
  background: var(--text);
  border-radius: var(--radius);
  box-shadow: var(--shadow-lg);
  color: var(--bg);
  pointer-events: auto;
}

.toast-icon {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: var(--success);
  color: #fff;
}

.toast-error .toast-icon {
  background: var(--danger);
}

.toast-icon svg {
  width: 14px;
  height: 14px;
}

.toast-message {
  font-size: 13.5px;
  line-height: 1.4;
}

.toast-close {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 24px;
  height: 24px;
  padding: 0;
  background: transparent;
  border: none;
  border-radius: 50%;
  color: inherit;
  opacity: 0.6;
}

.toast-close:hover {
  opacity: 1;
}

.toast-close svg {
  width: 14px;
  height: 14px;
}

.toast-enter-active,
.toast-leave-active {
  transition: opacity 0.22s ease, transform 0.22s cubic-bezier(0.2, 0.9, 0.3, 1.2);
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(10px) scale(0.96);
}

@media (max-width: 560px) {
  .toast-stack {
    right: 12px;
    left: 12px;
    bottom: 12px;
    align-items: stretch;
  }

  .toast {
    max-width: none;
  }
}
</style>
