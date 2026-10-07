<!-- TEMPLATE : ce que l'utilisateur voit et les boutons sur lesquels il clique. -->
<template>
  <section class="card clock" :aria-busy="loading">
    <header class="card-header">
      <div>
        <h3 class="card-title">
          Pointage
          <!-- On affiche l'état seulement après l'avoir récupéré auprès de l'API. -->
          <span v-if="ready" class="badge" :class="clockIn ? 'badge-success' : 'badge-muted'">
            {{ stateLabel }}
          </span>
        </h3>
        <p class="card-subtitle">Déclarez le début et la fin de votre journée</p>
      </div>
    </header>

    <div class="card-body clock-body">
      <div class="clock-status" :class="{ active: ready && clockIn }">
        <span class="clock-pulse" aria-hidden="true"></span>
        <div>
          <p class="clock-state serif">{{ stateLabel }}</p>
          <p class="clock-since num">{{ startDateLabel }}</p>
          <!-- En pause, le temps travaillé reste affiché mais n'avance plus. -->

        </div>
      </div>

      <div class="mobile-clock-time"><span>Heure actuelle</span><strong class="num">{{ currentTimeLabel }}</strong></div>
      <!-- @click appelle une méthode ; :disabled empêche de cliquer pendant l'attente. -->
      <button
        class="btn clock-btn"
        :class="clockIn ? 'btn-ghost' : 'btn-primary'"
        type="button"
        :disabled="loading || !ready"
        @click="clock()"
      >
        <svg viewBox="0 0 16 16" aria-hidden="true">
          <circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.5" />
          <path d="M8 5v3.2l2 1.3" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
        </svg>
        <strong class="clock-counter num" role="timer" aria-live="off">{{ elapsedTime }}</strong>
        <span>{{ clockButtonLabel }}</span>
      </button>

      <button v-if="ready && clockIn" class="btn btn-outline" type="button" :disabled="loading" @click="clock('pause')">
        Prendre une pause
      </button>
      <template v-if="ready && onBreak">
        <p class="clock-break-note">Les pauses ne sont pas comptées dans les heures travaillées.</p>
        <button class="btn btn-outline" type="button" :disabled="loading" @click="clock('departure')">
          Pointer mon départ
        </button>
      </template>

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
import { clockDate } from '../utils/missingDeparture'
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
      clockIn: false,       // true : travail en cours ; false : pause ou hors service.
      startDateTime: null, // Date de début ; null si aucune période n'est en cours.
      onBreak: false,      // Permet de distinguer une pause d'un départ.
      workedSeconds: 0,   // Travail déjà effectué avant les pauses de ce service.

      // L'heure actuelle change chaque seconde ; timerId permet d'arrêter la minuterie.
      currentTime: Date.now(),
      timerId: null,

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
    currentTimeLabel() { return new Date(this.currentTime).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) },
    loading() {
      // On attend si une lecture OU un enregistrement est en cours.
      return this.fetching || this.saving
    },

    stateLabel() {
      if (!this.ready) return 'État inconnu'
      if (this.onBreak) return 'En pause'
      return this.clockIn ? 'En service' : 'Hors service'
    },

    clockButtonLabel() {
      if (this.onBreak) return 'Reprendre'
      return this.clockIn ? 'Pointer mon départ' : 'Pointer mon arrivée'
    },

    // Total du service : les périodes déjà travaillées + la période en cours.
    elapsedTime() {
      if (!this.ready || (!this.clockIn && !this.onBreak)) return '00:00:00'

      let totalSeconds = this.workedSeconds
      if (this.clockIn && this.startDateTime) {
        // Z indique UTC. 1 000 millisecondes = 1 seconde.
        const start = Date.parse(`${this.startDateTime.replace(' ', 'T')}Z`)
        if (!Number.isFinite(start)) return '00:00:00'
        totalSeconds += Math.max(0, Math.floor((this.currentTime - start) / 1000))
      }

      const hours = Math.floor(totalSeconds / 3600)
      const minutes = Math.floor((totalSeconds % 3600) / 60)
      const seconds = totalSeconds % 60

      // padStart ajoute un zéro devant les chiffres seuls : 5 devient "05".
      return [hours, minutes, seconds].map((value) => String(value).padStart(2, '0')).join(':')
    },

    startDateLabel() {
      if (this.ready) {
        if (this.onBreak) return 'Le compteur reprendra à votre retour.'
        if (!this.clockIn) return 'Aucune période en cours'
        try { return `Depuis le ${clockDate(this.startDateTime).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })}` } catch { return 'Heure de début indisponible' }
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

  // En quittant le composant, arrêter la minuterie et ignorer les réponses en attente.
  beforeUnmount() {
    this.stopTimer()
    this.requestVersion += 1
  },

  methods: {
    // Mettre l'heure à jour immédiatement, puis chaque seconde, sans requête API.
    startTimer() {
      this.stopTimer() // Évite de lancer deux minuteries après une actualisation.
      this.currentTime = Date.now()
      this.timerId = setInterval(() => {
        // Reprendre l'heure réelle évite de prendre du retard si l'onglet a dormi.
        this.currentTime = Date.now()
      }, 1000)
    },

    stopTimer() {
      if (this.timerId !== null) {
        clearInterval(this.timerId)
        this.timerId = null
      }
    },

    // async permet d'utiliser await. await attend le résultat de l'appel avant de
    // continuer cette fonction ; le reste de la page peut continuer à fonctionner.

    // REFRESH : lit les pointages et retrouve l'état actuel de l'utilisateur.
    async refresh() {
      const userId = this.userId
      const version = ++this.requestVersion

      // 1. On commence une lecture : l'ancien état ne doit plus être présenté comme fiable.
      this.stopTimer()
      this.fetching = true
      this.ready = false
      this.error = ''
      this.clockIn = false
      this.startDateTime = null
      this.onBreak = false
      this.workedSeconds = 0

      try {
        // 2. Attend la liste renvoyée par GET /api/clocks/:userID.
        const clocks = await getClocks(userId)
        if (!this.isCurrentRequest(version, userId)) return
        if (!Array.isArray(clocks)) {
          throw new Error('Réponse de pointage invalide')
        }

        // 3. Relire les événements permet aussi de retrouver les pauses après un rechargement.
        this.restoreClockState(clocks)

        // 4. L'état est connu : Vue peut l'afficher et autoriser un nouveau pointage.
        this.ready = true
        if (this.clockIn) this.startTimer()
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

    // Phoenix renvoie les événements dans l'ordre, du plus ancien au plus récent.
    restoreClockState(clocks) {
      for (const entry of clocks) {
        // Les anciennes réponses sans kind restent lisibles.
        const kind = entry.kind || (entry.status ? 'arrival' : 'departure')
        const time = formatClockDate(entry.time)

        if (kind === 'arrival') this.workedSeconds = 0

        if (kind === 'arrival' || kind === 'resume') {
          this.clockIn = true
          this.onBreak = false
          this.startDateTime = time
        } else if (kind === 'pause') {
          if (this.startDateTime) {
            const start = Date.parse(`${this.startDateTime.replace(' ', 'T')}Z`)
            const end = Date.parse(`${time.replace(' ', 'T')}Z`)
            this.workedSeconds += Math.max(0, (end - start) / 1000)
          }
          this.clockIn = false
          this.onBreak = true
          this.startDateTime = null
        } else if (kind === 'departure') {
          this.clockIn = false
          this.onBreak = false
          this.startDateTime = null
          this.workedSeconds = 0
        } else {
          throw new Error('Type de pointage inconnu')
        }
      }
    },

    // Une seule méthode envoie les quatre actions à la même route API.
    async clock(kind = this.onBreak ? 'resume' : this.clockIn ? 'departure' : 'arrival') {
      // Sans état fiable, ou si un appel est en cours, on ne fait rien.
      if (this.loading || !this.ready) return

      const userId = this.userId
      const version = this.requestVersion
      this.saving = true
      this.error = ''

      try {
        // Arrivée et reprise : travail actif. Pause et départ : travail arrêté.
        // La date est envoyée en UTC au format "YYYY-MM-DD hh:mm:ss".
        await createClock(userId, {
          time: formatClockDate(new Date()),
          status: kind === 'arrival' || kind === 'resume',
          kind,
        })

        if (!this.isCurrentRequest(version, userId)) return

        // Une pause ou une sortie enregistre le travail terminé. Recharger les totaux.
        this.$emit('changed')
        await this.refresh()
      } catch (error) {
        if (!this.isCurrentRequest(version, userId)) return

        // Une coupure peut masquer un enregistrement réussi. Il faut relire l'état
        // avant de réessayer, pour éviter d'envoyer deux fois le même pointage.
        this.ready = false
        this.stopTimer()
        this.error = error.status === 422
          ? `${error.message}. Rafraîchis avant de réessayer.`
          : 'Pointage non confirmé. Rafraîchis avant de réessayer.'
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

.clock-elapsed {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin-top: 10px;
  font-size: 13px;
  color: var(--text-muted);
}

.clock-elapsed .num {
  font-size: 28px;
  font-weight: 600;
  line-height: 1.2;
  color: var(--accent);
}

.clock-btn {
  align-self: center;
  flex-direction: column;
  width: min(100%, 220px);
  aspect-ratio: 1;
  gap: 12px;
  padding: 24px;
  border-radius: 50%;
  font-size: 19px;
  line-height: 1.3;
  text-align: center;
  white-space: normal;
}

.clock-btn svg {
  width: 32px;
  height: 32px;
}

.refresh {
  align-self: center;
}

.clock-break-note {
  font-size: 13px;
  color: var(--text-muted);
  text-align: center;
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
.clock-counter { font-size: 32px; letter-spacing: -.04em; }
.clock-btn { background: var(--surface); border: 4px solid var(--brand); color: var(--title); width: 200px; padding: 18px; font-size: 12px; gap: 8px; }
.clock-btn:hover:not(:disabled) { background: var(--brand-soft); }
.clock-btn svg { width: 24px; height: 24px; }
.clock-status { padding: 0; background: none; justify-content: center; }
.clock-state { font-size: 14px; }
.clock-status .clock-since { font-size: 12px; }
.mobile-clock-time { display: none; }
@media (max-width: 760px) {
 .clock-body { margin: 0 16px 16px; padding: 22px 16px; background: var(--side-bg); color: var(--side-ink); border-radius: var(--radius); }
 .mobile-clock-time { display: flex; flex-direction: column; text-align: center; text-transform: uppercase; font-size: 10px; color: var(--side-muted); }
 .mobile-clock-time strong { color: var(--side-ink); font-size: 42px; line-height: 1.3; }
 .clock-state, .clock-since { color: var(--side-ink); }
 .clock-btn { width: 100%; aspect-ratio: auto; border: 0; border-radius: 8px; padding: 16px; background: #fff; color: #24584f; font-size: 14px; }
 .clock-counter { font-size: 26px; }
 .clock-body > .btn-outline { background: transparent; color: var(--side-ink); border-color: var(--side-muted); }
 .clock-body .refresh, .clock-break-note { color: var(--side-muted); }
 .clock-error { background: var(--surface); padding: 10px; border-radius: 6px; }
}
</style>
