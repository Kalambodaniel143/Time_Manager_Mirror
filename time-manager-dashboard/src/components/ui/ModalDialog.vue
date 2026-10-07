<template>
  <Teleport to="body"><div class="overlay" @click.self="close"><section ref="dialog" class="dialog card" role="dialog" aria-modal="true" :aria-labelledby="id" tabindex="-1" @keydown="keydown"><header class="dialog-header"><h2 :id="id" class="card-title">{{ title }}</h2><button class="btn btn-quiet btn-icon" type="button" aria-label="Fermer" :disabled="busy" @click="close"><AppIcon name="close" /></button></header><div class="dialog-body"><slot /></div></section></div></Teleport>
</template>
<script>
import AppIcon from './AppIcon.vue'
export default {
 name: 'ModalDialog', components: { AppIcon }, props: { title: { type: String, required: true }, id: { type: String, required: true }, busy: Boolean }, emits: ['close'],
 mounted() { this.previousFocus = document.activeElement; this.$refs.dialog.focus() },
 beforeUnmount() { this.previousFocus?.focus() },
 methods: {
  close() { if (!this.busy) this.$emit('close') },
  keydown(event) {
   if (event.key === 'Escape') this.close()
   if (event.key !== 'Tab') return
   const controls = [...this.$refs.dialog.querySelectorAll('button:not(:disabled), input:not(:disabled), textarea:not(:disabled), select:not(:disabled), a[href]')]
   const first = controls[0], last = controls.at(-1)
   if (!first) { event.preventDefault(); return }
   if (event.shiftKey && (document.activeElement === first || document.activeElement === this.$refs.dialog)) { event.preventDefault(); last.focus() }
   else if (!event.shiftKey && (document.activeElement === last || document.activeElement === this.$refs.dialog)) { event.preventDefault(); first.focus() }
  },
 },
}
</script>
