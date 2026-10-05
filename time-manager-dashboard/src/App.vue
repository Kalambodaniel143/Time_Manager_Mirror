<template>
  <RouterView v-if="!user || $route.meta.public" />

  <div v-else class="shell">
    <AppSidebar :role="user.role" :theme="theme" :space="persona.space" :user-id="userId" @update:theme="setTheme">
      <User :user="user" @logout="logout" />
    </AppSidebar>

    <main class="main">
      <WorkingTimes
        v-if="isOverlay && overlayUserId"
        ref="list"
        :userID="overlayUserId"
        :week="week"
        :username="persona.username"
        @changed="loadStats"
        @tour="openTour"
      />
      <RouterView v-slot="{ Component }">
        <component :is="Component" v-if="Component" :ref="routeRef" :key="$route.path" v-bind="routeBindings" />
      </RouterView>
    </main>

    <OnboardingTour v-if="tourOpen" :steps="tourSteps" @close="closeTour" />
  </div>

  <ToastStack />
</template>

<script>
import { RouterView } from 'vue-router'
import ToastStack from './components/ToastStack.vue'
import User from './components/User.vue'
import WorkingTimes from './components/WorkingTimes.vue'
import AppSidebar from './components/layout/AppSidebar.vue'
import OnboardingTour from './components/ui/OnboardingTour.vue'
import { personaFor } from './services/orgService'
import { getWorkingTimes } from './services/workingTimeService'
import { auth, logout } from './stores/auth'
import { durationInHours } from './utils/date'
import { applyTheme, readStorage, readTheme, writeStorage, writeTheme } from './utils/session'

const OVERLAY_ROUTES = ['workingTimeCreate', 'workingTimeEdit']
const TOUR_KEY = 'tm-tour-seen'

const TOUR_STEPS = [
  { title: 'Pointer, c’est un seul geste', text: 'Touchez le grand rond en arrivant, puis en partant. Le reste se calcule tout seul.' },
  { title: 'Chaque heure a sa couleur', text: 'Jour, nuit ×1,5, astreinte, heures sup. ×2 : la même couleur du planning à la fiche de paie.' },
  { title: 'Une erreur ? Signalez-la', text: 'Votre manager corrige la journée concernée. Vous voyez la correction dans « Mes heures », avec son auteur.' },
]

export default {
  name: 'App',

  components: { AppSidebar, OnboardingTour, RouterView, ToastStack, User, WorkingTimes },

  data() {
    return {
      theme: 'light',
      workingTimes: [],
      loadingStats: false,
      tourOpen: false,
      tourSteps: TOUR_STEPS,
      now: new Date(),
    }
  },

  computed: {
    // The logged-in user, from GET /api/auth/me or the login response.
    user() {
      return auth.user
    },

    userId() {
      return this.user ? this.user.id : null
    },

    // Demo content (planning, payroll...) still comes from the mocks; the
    // identity is the real user's.
    persona() {
      const mock = personaFor(this.user && this.user.role === 'administrator' ? 'admin' : this.user && this.user.role)
      if (!this.user) return mock

      return { ...mock, username: this.user.username, email: this.user.email, name: this.user.username }
    },

    overlayUserId() {
      return this.$route.params.userid || this.userId
    },

    isOverlay() {
      return OVERLAY_ROUTES.includes(this.$route.name)
    },

    week() {
      return this.$route.query.semaine || ''
    },

    routeRef() {
      return this.$route.name === 'workingTimes' ? 'list' : 'view'
    },

    routeProps() {
      const name = this.$route.name

      if (name === 'overview') {
        return { persona: this.persona, userId: this.userId, workingTimes: this.workingTimes, loading: this.loadingStats, now: this.now }
      }
      if (name === 'workingTimes') return { week: this.week, username: this.persona.username }
      if (name === 'planning' || name === 'payroll' || name === 'team') return { now: this.now }

      return {}
    },

    routeListeners() {
      if (this.$route.name === 'clock') return { onChanged: this.onPeriodsChanged }

      if (this.$route.name === 'workingTimes') return { onChanged: this.loadStats, onTour: this.openTour }

      if (OVERLAY_ROUTES.includes(this.$route.name)) {
        return {
          onSaved: this.onPeriodsChanged,
          onDeleted: this.onPeriodsChanged,
          onClose: this.closeOverlay,
        }
      }

      if (this.$route.name === 'overview') return { onChanged: this.onPeriodsChanged, onTour: this.openTour }
      if (this.$route.name === 'planning') return { onTour: this.openTour }

      return {}
    },

    routeBindings() {
      return { ...this.routeProps, ...this.routeListeners }
    },

    totalHours() {
      return this.sumHours(this.workingTimes)
    },
  },

  watch: {
    userId: {
      immediate: true,
      handler(id) {
        this.loadStats()
        // The theme may have been picked on the login page.
        this.setTheme(readTheme())
        this.tourOpen = Boolean(id) && this.user.role === 'employee' && !readStorage(TOUR_KEY)
      },
    },
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

    async onPeriodsChanged() {
      await this.loadStats()
      if (this.$refs.list) await this.$refs.list.getWorkingTimes()
    },

    setTheme(theme) {
      this.theme = theme
      applyTheme(theme)
      writeTheme(theme)
    },

    async logout() {
      this.tourOpen = false
      await logout()
      this.$router.push({ name: 'login' })
    },

    openTour() {
      this.tourOpen = true
    },

    closeTour() {
      this.tourOpen = false
      writeStorage(TOUR_KEY, '1')
    },

    closeOverlay() {
      this.$router.push({ name: 'workingTimes', params: { userID: this.$route.params.userid || this.userId }, query: this.$route.query })
    },
  },
}
</script>

<style scoped>
.shell {
  display: grid;
  grid-template-columns: 284px minmax(0, 1fr);
  min-height: 100vh;
}

.main {
  min-width: 0;
  padding: 38px 42px 56px;
}

@media (max-width: 900px) {
  .shell {
    display: block;
  }

  .main {
    padding: 24px 16px 48px;
  }
}
</style>
