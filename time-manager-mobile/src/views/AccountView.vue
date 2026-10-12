<template>
  <PageHeader title="Mon compte" eyebrow="Vos informations et préférences" />
  <ProfileCard />
  <PasswordCard />
  <PendingActions />
  <DisplayPrefs />

  <section class="card">
    <h2>Votre confidentialité</h2>
    <p class="small"><strong>{{ WHO_SEES[role] }}</strong> : heures d’arrivée et de départ, type d’heures.</p>
    <p class="small"><strong>Jamais enregistré</strong> : votre position, votre mot de passe sur ce téléphone.</p>
  </section>

  <DemoControls v-if="demo" />

  <p v-if="pending" class="notice-warn">
    {{ pending }} pointage(s) pas encore envoyé(s) : ils resteront sur ce téléphone et partiront à votre prochaine connexion.
  </p>
  <button type="button" class="btn-outline btn-block" @click="logout">Se déconnecter</button>
  <DeleteAccount />
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import ProfileCard from '@/components/account/ProfileCard.vue'
import PendingActions from '@/components/account/PendingActions.vue'
import PasswordCard from '@/components/account/PasswordCard.vue'
import DisplayPrefs from '@/components/account/DisplayPrefs.vue'
import DemoControls from '@/components/account/DemoControls.vue'
import DeleteAccount from '@/components/account/DeleteAccount.vue'
import { app } from '@/services/appState.js'
import { checkSession, logout } from '@/services/authService.js'
import { DATA_SOURCE } from '@/config/api.js'
import { WHO_SEES } from '@/ui/roleTexts.js'

export default {
  name: 'AccountView',
  components: { PageHeader, ProfileCard, PasswordCard, PendingActions, DisplayPrefs, DemoControls, DeleteAccount },
  data: () => ({ demo: DATA_SOURCE === 'mock', WHO_SEES }),
  computed: { pending: () => app.pending, role: () => app.user.role },
  created() { checkSession() },
  methods: { logout },
}
</script>
