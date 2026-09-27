<!-- TEMPLATE : ce que l'utilisateur voit et les boutons sur lesquels il clique. -->
<template>
  <section class="card clock" :aria-busy="loading">
    <header class="card-header">
      <div>
        <h3 class="card-title">
          Pointage
          <!-- On affiche l'état seulement après l'avoir récupéré auprès de l'API. -->
          <span v-if="ready" class="badge" :class="clockIn ? 'badge-success' : 'badge-muted'">
            {{ clockIn ? 'En cours' : 'Hors service' }}
          </span>
        </h3>
        <p class="card-subtitle">Déclarez le début et la fin de votre journée</p>
      </div>
    </header>

    <div class="card-body clock-body">
      <div class="clock-status" :class="{ active: ready && clockIn }">
        <span class="clock-pulse" aria-hidden="true"></span>
        <div>
          <p class="clock-state serif">{{ ready ? (clockIn ? 'En service' : 'Hors service') : 'État inconnu' }}</p>
          <p class="clock-since num">{{ startDateLabel }}</p>
        </div>
      </div>

      <!-- @click appelle une méthode ; :disabled empêche de cliquer pendant l'attente. -->
      <button
        class="btn clock-btn"
        :class="clockIn ? 'btn-ghost' : 'btn-primary'"
        type="button"
        :disabled="loading || !ready"
        @click="clock"
      >
        <svg viewBox="0 0 16 16" aria-hidden="true">
          <circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.5" />
          <path d="M8 5v3.2l2 1.3" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
        </svg>
        {{ clockIn ? 'Terminer ma journée' : 'Commencer ma journée' }}
      </button>

      <button class="btn btn-quiet btn-sm refresh" type="button" :disabled="loading" @click="refresh">
        {{ loading ? 'Actualisation…' : 'Actualiser le statut' }}
      </button>

      <!-- v-if affiche le message uniquement lorsque sa condition est remplie. -->
      <p v-if="error" class="clock-error" role="alert">{{ error }}</p>
    </div>
  </section>
</template>

<script>
// SCRIPT : les données du composant et les actions qui les mettent à jour.
// Le service réalise les requêtes HTTP. L'utilitaire prépare les dates en UTC.
import { getClocks, createClock } from '../services/clockService'
import { formatClockDate } from '../utils/clockDate'

export default {
  name: 'ClockManager',

  // Information reçue du parent ou du router : pour qui faut-il pointer ?
  props: {
    userId: { type: [Number, String], required: true },
  },

  // Le composant peut prévenir son parent qu'un pointage a été enregistré.
  emits: ['changed'],

  // Vue actualise l'affichage lorsque ces données changent.
  data() {
    return {
      // Les deux données demandées dans le sujet Epitech.
      clockIn: false,       // true : travail en cours ; false : hors service.
      startDateTime: null, // Date de début ; null si aucune période n'est en cours.

      // Les états de communication avec l'API.
      fetching: false, // Lecture des pointages en cours.
      saving: false,   // Enregistrement d'un pointage en cours.
      ready: false,    // L'état affiché a été récupéré et on peut s'y fier.
      error: '',       // Message à afficher ; une chaîne vide n'affiche rien.

      // Numéro de la dernière lecture, pour ignorer les réponses devenues anciennes.
      requestVersion: 0,
    }
  },

  // Valeurs calculées automatiquement à partir des données ci-dessus.
  computed: {
    loading() {
      // On attend si une lecture OU un enregistrement est en cours.
      return this.fetching || this.saving
    },

    startDateLabel() {
      if (this.ready) {
        return this.clockIn ? `Depuis ${this.startDateTime}` : 'Aucune période en cours'
      }
      if (this.loading) {
        return 'Chargement…'
      }
      return 'État indisponible'
    },
  },

  // Recharge les pointages à l'ouverture, puis à chaque changement d'utilisateur.
  watch: {
    userId: {
      immediate: true,
      handler() {
        this.refresh()
      },
    },
  },

  // Quand on quitte le composant, les réponses encore en attente deviennent anciennes.
  beforeUnmount() {
    this.requestVersion += 1
  },

  methods: {
    // async permet d'utiliser await. await attend le résultat de l'appel avant de
    // continuer cette fonction ; le reste de la page peut continuer à fonctionner.

    // REFRESH : lit les pointages et retrouve l'état actuel de l'utilisateur.
    async refresh() {
      const userId = this.userId
      const version = ++this.requestVersion

      // 1. On commence une lecture : l'ancien état ne doit plus être présenté comme fiable.
      this.fetching = true
      this.ready = false
      this.error = ''
      this.clockIn = false
      this.startDateTime = null

      try {
        // 2. Attend la liste renvoyée par GET /api/clocks/:userID.
        const clocks = await getClocks(userId)
        if (!this.isCurrentRequest(version, userId)) return
        if (!Array.isArray(clocks)) {
          throw new Error('Réponse de pointage invalide')
        }

        // 3. Phoenix classe les pointages du plus ancien au plus récent.
        // S'il n'y en a aucun, ?. évite une erreur et isWorking vaut false.
        const lastClock = clocks[clocks.length - 1]
        const isWorking = lastClock?.status === true
        const start = isWorking ? formatClockDate(lastClock.time) : null

        // 4. L'état est connu : Vue peut l'afficher et autoriser un nouveau pointage.
        this.clockIn = isWorking
        this.startDateTime = start
        this.ready = true
      } catch (error) {
        // Une lecture échouée laisse ready à false : on ne devine pas le statut.
        if (!this.isCurrentRequest(version, userId)) return
        this.error = error.status === 404
          ? 'Cet utilisateur est introuvable dans l’API.'
          : 'Impossible de récupérer les pointages. Vérifie la connexion à l’API.'
      } finally {
        // finally s'exécute après une réussite ou un échec.
        // Une ancienne lecture ne doit pas arrêter l'indicateur de la nouvelle.
        if (this.isCurrentRequest(version, userId)) {
          this.fetching = false
        }
      }
    },

    // CLOCK : enregistre une arrivée ou une sortie, puis relit l'état enregistré.
    async clock() {
      // Sans état fiable, ou si un appel est en cours, on ne fait rien.
      if (this.loading || !this.ready) return

      const userId = this.userId
      const version = this.requestVersion
      this.saving = true
      this.error = ''

      try {
        // ! inverse le booléen : au repos -> arrivée (true), au travail -> sortie (false).
        // La date est envoyée en UTC au format "YYYY-MM-DD hh:mm:ss".
        await createClock(userId, {
          time: formatClockDate(new Date()),
          status: !this.clockIn,
        })

        if (!this.isCurrentRequest(version, userId)) return

        // Le serveur a accepté le pointage : on prévient le parent et on relit la liste.
        this.$emit('changed')
        await this.refresh()
      } catch {
        if (!this.isCurrentRequest(version, userId)) return

        // Une coupure peut masquer un enregistrement réussi. Il faut relire l'état
        // avant de réessayer, pour éviter d'envoyer deux fois le même pointage.
        this.ready = false
        this.error = 'Pointage non confirmé. Rafraîchis avant de réessayer.'
      } finally {
        // La tentative d'enregistrement est terminée, même en cas d'erreur.
        this.saving = false
      }
    },

    // Protection si plusieurs réponses arrivent dans un ordre différent des demandes.
    // On utilise uniquement celle de la dernière lecture, pour l'utilisateur actuel.
    isCurrentRequest(version, userId) {
      return version === this.requestVersion && userId === this.userId
    },
  },
}
</script>

<!-- STYLE : l'apparence du panneau. scoped limite ces styles à ce composant. -->
<style scoped>
.clock {
  display: flex;
  flex-direction: column;
}

/* Place les informations et les boutons les uns sous les autres. */
.clock-body {
  display: flex;
  flex: 1;
  flex-direction: column;
  justify-content: center;
  gap: 14px;
}

/* Encadré contenant la date de début. Les variables CSS viennent du thème commun. */
.clock-status {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 16px 18px;
  background: var(--surface-muted);
  border-radius: var(--radius);
}

.clock-pulse {
  position: relative;
  flex-shrink: 0;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--text-subtle);
}

.clock-status.active .clock-pulse {
  background: var(--success);
}

.clock-status.active .clock-pulse::after {
  content: '';
  position: absolute;
  inset: -5px;
  border: 2px solid var(--success);
  border-radius: 50%;
  animation: pulse 1.8s ease-out infinite;
}

.clock-state {
  font-size: 18px;
  line-height: 1.25;
}

.clock-since {
  font-size: 13px;
  color: var(--text-muted);
}

.clock-btn {
  padding: 13px 18px;
  font-size: 14.5px;
}

.refresh {
  align-self: center;
}

@keyframes pulse {
  from {
    opacity: 0.8;
    transform: scale(0.6);
  }
  to {
    opacity: 0;
    transform: scale(1.6);
  }
}

/* Rend visible le fait qu'un bouton est temporairement désactivé. */
button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.clock-error {
  color: var(--danger);
  font-size: 13px;
}
</style>
