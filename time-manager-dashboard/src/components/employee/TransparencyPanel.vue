<template>
  <section class="transparency card">
    <h2 class="card-title">{{ $t("Ce que voit votre manager") }}</h2>

    <p class="group-title"><AppIcon name="eye" /> {{ $t("Visible par votre manager") }}</p>
    <ul class="list">
      <li v-for="item in visible" :key="item"><AppIcon name="check" />{{ $t(item) }}</li>
    </ul>

    <p class="group-title"><AppIcon class="is-ok" name="shield" /> {{ $t("Jamais enregistré") }}</p>
    <ul class="list">
      <li v-for="item in never" :key="item"><AppIcon name="eye-off" />{{ $t(item) }}</li>
    </ul>

    <p class="footer">{{ $t("Votre responsable consulte les heures des membres des équipes qu’il gère. L’administration consulte les comptes de son organisation.") }}</p>
  </section>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import { isDemoData } from '../../services/orgService'

export default {
  name: 'TransparencyPanel',

  components: { AppIcon },

  data() {
    return {
      never: ['Votre activité sur l’ordinateur ou le téléphone', 'Votre position', 'Les sites et applications que vous utilisez'],
    }
  },

  computed: {
    visible() { return isDemoData() ? ['Vos heures d’arrivée et de départ', 'Le type de chaque heure (jour, nuit, astreinte…)', 'Les notes que vous choisissez de partager'] : ['Vos heures d’arrivée et de départ', 'Vos périodes travaillées et leurs durées', 'Votre identifiant, votre nom et votre e-mail'] },
  },
}
</script>

<style scoped>
.transparency {
  padding: 24px 24px 22px;
}

.transparency > .card-title {
  font-size: 19px;
}

.group-title {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 20px 0 8px;
  font-size: 16px;
  font-weight: 700;
}

.group-title svg {
  width: 20px;
  height: 20px;
  color: var(--title);
}

.group-title .is-ok {
  color: var(--ok-fg);
}

.list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 0;
  list-style: none;
  font-size: 13px;
}

.list li {
  display: flex;
  gap: 10px;
}

.list svg {
  width: 16px;
  height: 16px;
  margin-top: 3px;
  color: var(--text-muted);
}

.footer {
  margin-top: 20px;
  padding-top: 18px;
  border-top: 1px solid var(--border);
  font-size: 14px;
  color: var(--text-muted);
}
</style>
