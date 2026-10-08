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
import { getClocks, createClock } from '../services/clockService'
import { clockDate } from '../utils/missingDeparture'
import { formatClockDate } from '../utils/clockDate'

export default {
  name: 'ClockManager',

  props: {
    userId: { type: [Number, String], required: true },
  },

  emits: ['changed'],

  data() {
    return {
      clockIn: false,
      startDateTime: null,
      onBreak: false,
      workedSeconds: 0,

      currentTime: Date.now(),
      timerId: null,

      fetching: false,
      saving: false,
      ready: false,
      error: '',

      requestVersion: 0,
    }
  },

  computed: {
    currentTimeLabel() { return new Date(this.currentTime).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }) },
    loading() {
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

    elapsedTime() {
      if (!this.ready || (!this.clockIn && !this.onBreak)) return '00:00:00'

      let totalSeconds = this.workedSeconds
      if (this.clockIn && this.startDateTime) {
        const start = Date.parse(`${this.startDateTime.replace(' ', 'T')}Z`)
        if (!Number.isFinite(start)) return '00:00:00'
        totalSeconds += Math.max(0, Math.floor((this.currentTime - start) / 1000))
      }

      const hours = Math.floor(totalSeconds / 3600)
      const minutes = Math.floor((totalSeconds % 3600) / 60)
      const seconds = totalSeconds % 60

      return [hours, minutes, seconds].map((value) => String(value).padStart(2, '0')).join(':')
    },

    startDateLabel() {
      if (!this.ready) return this.loading ? 'Chargement…' : 'État indisponible'
      if (this.onBreak) return 'Le compteur reprendra à votre retour.'
      if (!this.clockIn) return 'Aucune période en cours'
      try {
        return `Depuis le ${clockDate(this.startDateTime).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })}`
      } catch {
        return 'Heure de début indisponible'
      }
    },
  },

  watch: {
    userId: { immediate: true, handler: 'refresh' },
  },

  beforeUnmount() {
    this.stopTimer()
    this.requestVersion += 1
  },

  methods: {
    startTimer() {
      this.stopTimer()
      this.currentTime = Date.now()
      this.timerId = setInterval(() => {
        this.currentTime = Date.now()
      }, 1000)
    },

    stopTimer() {
      clearInterval(this.timerId)
      this.timerId = null
    },

    async refresh() {
      const userId = this.userId
      const version = ++this.requestVersion

      this.stopTimer()
      this.fetching = true
      this.ready = false
      this.error = ''
      this.clockIn = false
      this.startDateTime = null
      this.onBreak = false
      this.workedSeconds = 0

      try {
        const clocks = await getClocks(userId)
        if (!this.isCurrentRequest(version, userId)) return
        if (!Array.isArray(clocks)) throw new Error('Réponse de pointage invalide')

        this.restoreClockState(clocks)

        this.ready = true
        if (this.clockIn) this.startTimer()
      } catch (error) {
        if (!this.isCurrentRequest(version, userId)) return
        this.error = error.status === 404
          ? 'Cet utilisateur est introuvable dans l’API.'
          : 'Impossible de récupérer les pointages. Vérifie la connexion à l’API.'
      } finally {
        if (this.isCurrentRequest(version, userId)) this.fetching = false
      }
    },

    restoreClockState(clocks) {
      // L'API trie par date puis identifiant, y compris à la même seconde.
      for (const entry of clocks) {
        // Compatibilité avec les pointages antérieurs à l'ajout de kind.
        const kind = entry.kind || (entry.status ? 'arrival' : 'departure')
        const time = formatClockDate(entry.time)

        if (!['arrival', 'resume', 'pause', 'departure'].includes(kind)) throw new Error('Type de pointage inconnu')
        if (kind === 'arrival' || kind === 'departure') this.workedSeconds = 0
        if (kind === 'pause' && this.startDateTime) {
          this.workedSeconds += Math.max(0, (clockDate(time) - clockDate(this.startDateTime)) / 1000)
        }

        this.clockIn = kind === 'arrival' || kind === 'resume'
        this.onBreak = kind === 'pause'
        this.startDateTime = this.clockIn ? time : null
      }
    },

    async clock(kind = this.onBreak ? 'resume' : this.clockIn ? 'departure' : 'arrival') {
      if (this.loading || !this.ready) return

      const userId = this.userId
      const version = this.requestVersion
      this.saving = true
      this.error = ''

      try {
        await createClock(userId, {
          time: formatClockDate(new Date()),
          status: kind === 'arrival' || kind === 'resume',
          kind,
        })

        if (!this.isCurrentRequest(version, userId)) return

        this.$emit('changed')
        await this.refresh()
      } catch (error) {
        if (!this.isCurrentRequest(version, userId)) return

        // Une réponse perdue peut masquer une écriture réussie : relire avant de réessayer.
        this.ready = false
        this.stopTimer()
        this.error = error.status === 422
          ? `${error.message}. Rafraîchis avant de réessayer.`
          : 'Pointage non confirmé. Rafraîchis avant de réessayer.'
      } finally {
        this.saving = false
      }
    },

    isCurrentRequest(version, userId) {
      // La version distingue aussi une navigation A → B → A.
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
