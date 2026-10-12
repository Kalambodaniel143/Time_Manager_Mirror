<template>
  <div class="password-field">
    <input :id="id" :value="modelValue" :type="visible ? 'text' : 'password'" :autocomplete="autocomplete"
      :minlength="autocomplete === 'new-password' ? 8 : null" maxlength="128" required @input="$emit('update:modelValue', $event.target.value)" />
    <button type="button" class="btn-quiet" :aria-label="visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe'" @click="visible = !visible">
      <component :is="visible ? EyeOff : Eye" :size="20" />
    </button>
  </div>
</template>

<script>
import { markRaw } from 'vue'
import { Eye, EyeOff } from 'lucide-vue-next'

// Champ mot de passe avec bouton « afficher / masquer ».
export default {
  name: 'PasswordInput',
  props: {
    id: { type: String, required: true },
    modelValue: { type: String, default: '' },
    autocomplete: { type: String, default: 'new-password' },
  },
  emits: ['update:modelValue'],
  data: () => ({ visible: false, Eye: markRaw(Eye), EyeOff: markRaw(EyeOff) }),
}
</script>
