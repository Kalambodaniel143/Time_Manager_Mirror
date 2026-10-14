<template>
  <button type="button" class="icon-btn round" :class="{ spinning: busy }" :disabled="busy" :aria-label="$t('Actualiser')" :title="$t('Actualiser')"
    @click="$emit('refresh')">
    <RefreshCw :size="18" aria-hidden="true" />
  </button>
</template>

<script>
import { RefreshCw } from 'lucide-vue-next'

// Petit bouton rond « actualiser » placé à droite du titre.
export default {
  name: 'RefreshButton',
  components: { RefreshCw },
  props: { busy: Boolean },
  emits: ['refresh'],
}
</script>
