<template>
  <PageHeader :title="$t('Mon compte')" :eyebrow="$t('Vos informations et préférences')" />
  <ProfileCard />
  <PasswordCard v-if="role === 'administrator'" />
  <PasswordRequestCard v-else />
  <PendingActions />
  <DisplayPrefs />

  <section class="card">
    <h2>{{ $t('Votre confidentialité') }}</h2>
    <p class="small"><strong>{{ WHO_SEES[role] }}</strong> {{ $t(': heures d’arrivée et de départ, type d’heures.') }}</p>
    <p class="small"><strong>{{ $t('Jamais enregistré') }}</strong> {{ $t(': votre position, votre mot de passe sur ce téléphone.') }}</p>
  </section>

  <p v-if="pending" class="notice-warn">
    {{ $t('{0} pointage(s) pas encore envoyé(s) : ils resteront sur ce téléphone et partiront à votre prochaine connexion.', [pending]) }}
  </p>
  <button type="button" class="btn-outline btn-block" @click="logout">{{ $t('Se déconnecter') }}</button>
  <DeleteAccount />
</template>

<script>
import PageHeader from '@/components/common/PageHeader.vue'
import ProfileCard from '@/components/account/ProfileCard.vue'
import PendingActions from '@/components/account/PendingActions.vue'
import PasswordCard from '@/components/account/PasswordCard.vue'
import PasswordRequestCard from '@/components/account/PasswordRequestCard.vue'
import DisplayPrefs from '@/components/account/DisplayPrefs.vue'
import DeleteAccount from '@/components/account/DeleteAccount.vue'
import { app } from '@/services/appState.js'
import { checkSession, logout } from '@/services/authService.js'
import { WHO_SEES } from '@/ui/roleTexts.js'

export default {
  name: 'AccountView',
  components: { PageHeader, ProfileCard, PasswordCard, PasswordRequestCard, PendingActions, DisplayPrefs, DeleteAccount },
  data: () => ({ WHO_SEES }),
  computed: { pending: () => app.pending, role: () => app.user.role },
  created() { checkSession() },
  methods: { logout },
}
</script>
