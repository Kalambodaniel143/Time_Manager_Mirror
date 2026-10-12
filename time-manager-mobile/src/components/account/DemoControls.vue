<template>
  <section class="card demo-card">
    <h2>Outils de test · mode démo</h2>
    <p class="small muted">
      Cette carte n’existe qu’avec les données fictives (VITE_DATA_SOURCE=mock). Elle sert à jouer
      les scénarios hors ligne pendant la démonstration, sans couper le Wi-Fi. Elle disparaît en mode API.
    </p>
    <label class="choice">
      <input v-model="settings.serverDown" type="checkbox" @change="save('serverDown')" />
      Couper le serveur (tester le pointage hors ligne)
    </label>
    <label class="choice">
      <input v-model="settings.loseNextResponse" type="checkbox" @change="save('loseNextResponse')" />
      Perdre la réponse du prochain envoi (tester l’anti-doublon)
    </label>
    <label class="choice">
      <input v-model="settings.sessionExpired" type="checkbox" @change="save('sessionExpired')" />
      Faire expirer la session (tester la reconnexion)
    </label>
  </section>
</template>

<script>
import { getMockSettings, setMockSetting } from '@/services/mock/server.js'
import { checkSession } from '@/services/authService.js'
import { syncNow } from '@/services/syncService.js'

// Visible seulement en mode MOCK : simule les pannes du serveur pour les tests.
export default {
  name: 'DemoControls',
  data: () => ({ settings: getMockSettings() }),
  methods: {
    save(name) {
      setMockSetting(name, this.settings[name])
      checkSession().then(syncNow) // le serveur fictif répond selon le nouveau réglage
    },
  },
}
</script>
