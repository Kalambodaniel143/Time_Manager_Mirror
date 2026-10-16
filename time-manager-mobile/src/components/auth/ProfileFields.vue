<template>
  <div class="form-grid">
    <div class="dates">
      <label>{{ $t('Prénom') }} <input v-model.trim="model.first_name" autocomplete="given-name" maxlength="100" required /></label>
      <label>{{ $t('Nom') }} <input v-model.trim="model.last_name" autocomplete="family-name" maxlength="100" required /></label>
    </div>
    <label for="profile-email">{{ $t('Adresse e-mail') }}</label>
    <input id="profile-email" v-model.trim="model.email" type="email" autocomplete="email" maxlength="254" required />
    <template v-if="extended">
      <label for="gender">{{ $t('Genre') }}</label>
      <select id="gender" v-model="model.gender" required>
        <option v-for="(label, value) in GENDERS" :key="value" :value="value">{{ label }}</option>
      </select>
      <div class="dates">
        <label>{{ $t('Date de naissance') }} <input v-model="model.birth_date" type="date" min="1900-01-01" :max="today" required /></label>
        <label>{{ $t('Lieu de naissance') }} <input v-model.trim="model.birth_place" maxlength="100" required /></label>
      </div>
    </template>
  </div>
</template>

<script>
import { t } from '@/i18n/index.js'
import { localDay } from '@/ui/dates.js'

const GENDERS = { female: t('Femme'), male: t('Homme'), non_binary: t('Non binaire'), unspecified: t('Je préfère ne pas préciser') }

// Identité demandée par le serveur. extended = champs exigés pour rejoindre une organisation.
// v-model = objet profil, modifié en place.
export default {
  name: 'ProfileFields',
  props: { modelValue: { type: Object, required: true }, extended: Boolean },
  data: () => ({ GENDERS, today: localDay(new Date()) }),
  computed: { model() { return this.modelValue } },
}
</script>
