<template>
  <div class="shell">
    <header class="topbar">
      <div class="topbar-inner">
        <RouterLink class="brand" :to="{ name: 'overview' }">
          <span class="brand-mark" aria-hidden="true">
            <svg viewBox="0 0 24 24">
              <circle cx="12" cy="12" r="7.5" fill="none" stroke="currentColor" stroke-width="2" />
              <path d="M12 8v4.4l2.8 1.7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            </svg>
          </span>
          <span class="brand-text">
            <span class="brand-name serif">Time Manager</span>
            <span class="brand-sub">Mairie de Gotham</span>
          </span>
        </RouterLink>

        <nav v-if="userId" class="nav" aria-label="Navigation principale">
          <RouterLink class="nav-link" :to="{ name: 'overview' }" exact-active-class="is-active">Aujourd'hui</RouterLink>
          <RouterLink class="nav-link" :to="{ name: 'workingTimes', params: { userID: userId } }" active-class="is-active">Mes heures</RouterLink>
          <RouterLink class="nav-link" :to="{ name: 'clock', params: { userid: userId } }" active-class="is-active">Pointage</RouterLink>
          <RouterLink class="nav-link" :to="{ name: 'chartManager', params: { userid: userId } }" active-class="is-active">Tendances</RouterLink>
        </nav>

        <div class="topbar-actions">
          <button
            class="btn btn-quiet btn-icon"
            type="button"
            :aria-label="theme === 'dark' ? 'Passer en thème clair' : 'Passer en thème sombre'"
            @click="toggleTheme"
          >
            <svg v-if="theme === 'dark'" viewBox="0 0 16 16" aria-hidden="true">
              <circle cx="8" cy="8" r="3" fill="none" stroke="currentColor" stroke-width="1.5" />
              <path d="M8 1.5v1.5M8 13v1.5M1.5 8H3M13 8h1.5M3.4 3.4l1 1M11.6 11.6l1 1M3.4 12.6l1-1M11.6 4.4l1-1" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" />
            </svg>
            <svg v-else viewBox="0 0 16 16" aria-hidden="true">
              <path d="M13.5 9.5A5.5 5.5 0 0 1 6.5 2.5a5.5 5.5 0 1 0 7 7z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" />
            </svg>
          </button>
          <User ref="user" :user-id="userId" @update:user-id="setUser" @loaded="onUserLoaded" />
        </div>
      </div>
    </header>

    <main class="main">
      <section v-if="!userId" class="welcome card">
        <svg viewBox="0 0 160 120" aria-hidden="true">
          <circle cx="80" cy="60" r="44" fill="var(--accent-soft)" />
          <circle cx="80" cy="60" r="30" fill="none" stroke="var(--accent)" stroke-width="3" />
          <path d="M80 42v18l12 7" fill="none" stroke="var(--accent)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" />
          <circle cx="126" cy="28" r="6" fill="var(--border-strong)" />
          <circle cx="32" cy="90" r="4" fill="var(--border-strong)" />
        </svg>
        <h1 class="welcome-title serif">Bienvenue sur Time Manager</h1>
        <p class="welcome-text">
          Pour commencer, créez votre profil. Vous pourrez ensuite déclarer vos heures et suivre votre semaine d'un coup d'œil.
        </p>
        <button class="btn btn-primary" type="button" @click="$refs.user.openCreate()">Créer mon profil</button>
      </section>

      <template v-else>
        <template v-if="showOverview">
          <section class="hero">
            <p class="hero-date">{{ todayLabel }}</p>
            <h1 class="hero-title serif">
              {{ greetingText }}<template v-if="currentFirstName">, <em>{{ currentFirstName }}</em></template>.
            </h1>
            <p class="hero-lede">
              <template v-if="loadingStats">On prépare votre résumé…</template>
              <template v-else-if="weekHours > 0">
                Cette semaine, vous avez travaillé <strong class="num">{{ format(weekHours) }}</strong>
                sur {{ weekDays }} jour{{ weekDays > 1 ? 's' : '' }}.
                <template v-if="lastEntry">Dernière période : {{ lastEntryLabel }}.</template>
              </template>
              <template v-else>Pas encore d'heures cette semaine. Tout commence par une première période.</template>
            </p>
          </section>

          <section class="kpis" aria-label="Indicateurs">
            <article v-for="kpi in kpis" :key="kpi.label" class="kpi card">
              <p class="kpi-label">{{ kpi.label }}</p>
              <span v-if="loadingStats" class="skeleton kpi-skeleton"></span>
              <p v-else class="kpi-value serif num">{{ kpi.value }}</p>
              <p class="kpi-hint">{{ kpi.hint }}</p>
            </article>
          </section>

          <div class="grid">
            <ClockManager :user-id="userId" @changed="loadStats" />
            <ChartManager :user-id="userId" />
          </div>

          <WorkingTimes ref="list" :userID="userId" @changed="loadStats" />
        </template>

        <RouterView v-if="$route.name !== 'overview'" v-slot="{ Component }">
          <component :is="Component" :key="$route.fullPath" v-bind="routeListeners" />
        </RouterView>
      </template>
    </main>

    <footer class="footer">
      <span>Time Manager · Mairie de Gotham</span>
      <div class="footer-status">
        <span class="badge" :class="useMock ? 'badge-muted' : 'badge-success'">
          <span class="dot"></span>
          {{ useMock ? 'Données de démonstration' : `API ${apiUrl}` }}
        </span>
        <span class="badge" :class="clockUseMock ? 'badge-muted' : 'badge-success'">
          <span class="dot"></span>
          {{ clockUseMock ? 'Pointages : simulation' : 'Pointages : API' }}
        </span>
      </div>
    </footer>

    <ToastStack />
  </div>
</template>

<script>
import { RouterLink, RouterView } from 'vue-router'
import ChartManager from './components/ChartManager.vue'
import ClockManager from './components/ClockManager.vue'
import ToastStack from './components/ToastStack.vue'
import User from './components/User.vue'
import WorkingTimes from './components/WorkingTimes.vue'
import { API_URL, CLOCK_USE_MOCK, DEFAULT_USER_ID, USE_MOCK } from './config'
import { getWorkingTimes } from './services/workingTimeService'
import {
  durationInHours,
  formatDuration,
  formatHumanTime,
  formatLongDate,
  startOfWeek,
  toDateInput,
} from './utils/date'
import { firstName, greeting } from './utils/people'

const OVERLAY_ROUTES = ['workingTimeCreate', 'workingTimeEdit']

function readStorage(key) {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}

function writeStorage(key, value) {
  try {
    if (value === null) localStorage.removeItem(key)
    else localStorage.setItem(key, value)
  } catch {
    return
  }
}

export default {
  name: 'App',

  components: { ChartManager, ClockManager, RouterLink, RouterView, ToastStack, User, WorkingTimes },

  data() {
    const stored = Number(readStorage('tm-user'))

    return {
      userId: stored > 0 ? stored : DEFAULT_USER_ID,
      currentUser: null,
      theme: 'light',
      workingTimes: [],
      loadingStats: false,
      useMock: USE_MOCK,
      clockUseMock: CLOCK_USE_MOCK,
      apiUrl: API_URL,
      now: new Date(),
    }
  },

  computed: {
    showOverview() {
      return this.$route.name === 'overview' || OVERLAY_ROUTES.includes(this.$route.name)
    },

    routeListeners() {
      if (this.$route.name === 'workingTimes') return { onChanged: this.loadStats }

      if (OVERLAY_ROUTES.includes(this.$route.name)) {
        return {
          onSaved: this.onRoutedChange,
          onDeleted: this.onRoutedChange,
          onClose: this.closeOverlay,
        }
      }

      return {}
    },

    greetingText() {
      return greeting(this.now)
    },

    currentFirstName() {
      return firstName(this.currentUser)
    },

    todayLabel() {
      const label = formatLongDate(this.now)
      return label.charAt(0).toUpperCase() + label.slice(1)
    },

    weekEntries() {
      const monday = toDateInput(startOfWeek(this.now))
      return this.workingTimes.filter((entry) => entry.start.slice(0, 10) >= monday)
    },

    weekHours() {
      return this.sumHours(this.weekEntries)
    },

    weekDays() {
      return new Set(this.weekEntries.map((entry) => entry.start.slice(0, 10))).size
    },

    totalHours() {
      return this.sumHours(this.workingTimes)
    },

    daysWorked() {
      return new Set(this.workingTimes.map((entry) => entry.start.slice(0, 10))).size
    },

    longestEntry() {
      return this.workingTimes.reduce((best, entry) => {
        if (!best) return entry
        return durationInHours(entry.start, entry.end) > durationInHours(best.start, best.end) ? entry : best
      }, null)
    },

    lastEntry() {
      return this.workingTimes.reduce(
        (latest, entry) => (!latest || entry.start > latest.start ? entry : latest),
        null,
      )
    },

    lastEntryLabel() {
      const entry = this.lastEntry
      if (!entry) return ''

      return `${formatLongDate(entry.start)}, de ${formatHumanTime(entry.start)} à ${formatHumanTime(entry.end)}`
    },

    kpis() {
      const longest = this.longestEntry

      return [
        {
          label: 'Cette semaine',
          value: formatDuration(this.weekHours),
          hint: this.weekDays ? `sur ${this.weekDays} jour${this.weekDays > 1 ? 's' : ''}` : 'rien pour le moment',
        },
        {
          label: 'Moyenne par jour',
          value: formatDuration(this.daysWorked ? this.totalHours / this.daysWorked : 0),
          hint: `sur ${this.daysWorked} jour${this.daysWorked > 1 ? 's' : ''} travaillé${this.daysWorked > 1 ? 's' : ''}`,
        },
        {
          label: 'Plus longue journée',
          value: longest ? formatDuration(durationInHours(longest.start, longest.end)) : '0h00',
          hint: longest ? `le ${formatLongDate(longest.start)}` : '—',
        },
        {
          label: 'Total enregistré',
          value: formatDuration(this.totalHours),
          hint: `${this.workingTimes.length} période${this.workingTimes.length > 1 ? 's' : ''}`,
        },
      ]
    },
  },

  watch: {
    userId: {
      immediate: true,
      handler(value) {
        writeStorage('tm-user', value ? String(value) : null)
        this.loadStats()
      },
    },

    '$route.params': {
      immediate: true,
      handler(params) {
        const param = params.userID || params.userid
        if (param && Number(param) !== this.userId) this.userId = Number(param)
      },
    },
  },

  created() {
    const stored = readStorage('tm-theme')
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    this.applyTheme(stored || (prefersDark ? 'dark' : 'light'))
  },

  mounted() {
    this.clock = setInterval(() => {
      this.now = new Date()
    }, 60000)
  },

  beforeUnmount() {
    clearInterval(this.clock)
  },

  methods: {
    format(hours) {
      return formatDuration(hours)
    },

    sumHours(entries) {
      return entries.reduce((sum, entry) => sum + durationInHours(entry.start, entry.end), 0)
    },

    async loadStats() {
      if (!this.userId) {
        this.workingTimes = []
        return
      }

      this.loadingStats = true

      try {
        this.workingTimes = (await getWorkingTimes(this.userId)) || []
      } catch {
        this.workingTimes = []
      } finally {
        this.loadingStats = false
      }
    },

    setUser(id) {
      this.userId = id

      const name = this.$route.name
      if (!id || name === 'overview') return

      if (name === 'workingTimes') this.$router.replace({ name, params: { userID: id } })
      else if (name === 'clock' || name === 'chartManager') this.$router.replace({ name, params: { userid: id } })
      else this.$router.replace({ name: 'overview' })
    },

    onUserLoaded(user) {
      this.currentUser = user
    },

    async onRoutedChange() {
      await this.loadStats()
      if (this.$refs.list) this.$refs.list.getWorkingTimes()
    },

    closeOverlay() {
      this.$router.push({ name: 'overview' })
    },

    applyTheme(theme) {
      this.theme = theme
      document.documentElement.setAttribute('data-theme', theme)
      const meta = document.querySelector('meta[name="theme-color"]')
      if (meta) meta.setAttribute('content', theme === 'dark' ? '#15120e' : '#f6f2ea')
    },

    toggleTheme() {
      const next = this.theme === 'dark' ? 'light' : 'dark'
      this.applyTheme(next)
      writeStorage('tm-theme', next)
    },
  },
}
</script>

<style scoped>
.shell {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

.topbar {
  position: sticky;
  top: 0;
  z-index: 30;
  background: color-mix(in srgb, var(--bg) 82%, transparent);
  border-bottom: 1px solid var(--border);
  backdrop-filter: saturate(1.4) blur(12px);
}

.topbar-inner {
  display: flex;
  align-items: center;
  gap: 24px;
  max-width: 1200px;
  margin: 0 auto;
  padding: 12px 24px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 11px;
  color: inherit;
  text-decoration: none;
}

.brand-mark {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: 12px;
  background: var(--accent);
  color: var(--accent-text);
  box-shadow: 0 6px 14px -6px color-mix(in srgb, var(--accent) 70%, transparent);
}

.brand-mark svg {
  width: 22px;
  height: 22px;
}

.brand-text {
  display: flex;
  flex-direction: column;
  line-height: 1.2;
}

.brand-name {
  font-size: 17px;
  font-weight: 500;
}

.brand-sub {
  font-size: 12px;
  color: var(--text-muted);
}

.nav {
  display: flex;
  gap: 2px;
  margin: 0 auto;
  padding: 4px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 999px;
}

.nav-link {
  padding: 7px 15px;
  border-radius: 999px;
  font-size: 13.5px;
  font-weight: 500;
  color: var(--text-muted);
  text-decoration: none;
  white-space: nowrap;
  transition: background-color 0.15s ease, color 0.15s ease;
}

.nav-link:hover {
  color: var(--text);
}

.nav-link.is-active {
  background: var(--accent-soft);
  color: var(--accent);
}

.topbar-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
}

.nav + .topbar-actions {
  margin-left: 0;
}

.main {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 22px;
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 36px 24px 48px;
}

.hero {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 4px 4px 10px;
}

.hero-date {
  font-size: 13.5px;
  font-weight: 500;
  color: var(--text-muted);
}

.hero-title {
  font-size: clamp(32px, 5vw, 46px);
  font-weight: 400;
  line-height: 1.08;
  letter-spacing: -0.02em;
}

.hero-title em {
  font-style: italic;
  color: var(--accent);
}

.hero-lede {
  max-width: 620px;
  font-size: 16px;
  color: var(--text-muted);
}

.hero-lede strong {
  color: var(--text);
  font-weight: 600;
}

.kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.kpi {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 18px 20px 16px;
}

.kpi-label {
  font-size: 13px;
  font-weight: 500;
  color: var(--text-muted);
}

.kpi-value {
  font-size: 32px;
  line-height: 1.15;
  letter-spacing: -0.02em;
}

.kpi-skeleton {
  width: 88px;
  height: 37px;
}

.kpi-hint {
  font-size: 12.5px;
  color: var(--text-subtle);
}

.grid {
  display: grid;
  grid-template-columns: minmax(280px, 1fr) minmax(0, 1.8fr);
  gap: 22px;
  align-items: stretch;
}

.welcome {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  max-width: 560px;
  margin: 40px auto 0;
  padding: 44px 32px;
  text-align: center;
}

.welcome svg {
  width: 150px;
  margin-bottom: 4px;
}

.welcome-title {
  font-size: 30px;
  font-weight: 400;
}

.welcome-text {
  max-width: 420px;
  margin-bottom: 8px;
  color: var(--text-muted);
}

.footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 10px 16px;
  width: 100%;
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px 24px 28px;
  font-size: 12.5px;
  color: var(--text-subtle);
}

.footer-status {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

@media (max-width: 1000px) {
  .kpis {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .grid {
    grid-template-columns: minmax(0, 1fr);
  }
}

@media (max-width: 860px) {
  .topbar-inner {
    flex-wrap: wrap;
    gap: 12px;
  }

  .nav {
    order: 3;
    width: 100%;
    margin: 0;
    overflow-x: auto;
  }

  .nav-link {
    flex: 1;
    text-align: center;
  }

  .topbar-actions,
  .nav + .topbar-actions {
    margin-left: auto;
  }
}

@media (max-width: 560px) {
  .topbar-inner {
    padding: 10px 16px;
  }

  .main {
    padding: 24px 16px 40px;
    gap: 16px;
  }

  .brand-sub {
    display: none;
  }

  .nav-link {
    padding: 7px 8px;
    font-size: 13px;
  }

  .kpis {
    gap: 10px;
  }

  .kpi {
    padding: 14px 16px;
  }

  .kpi-value {
    font-size: 26px;
  }

  .footer {
    flex-direction: column;
    padding: 16px;
  }
}
</style>
