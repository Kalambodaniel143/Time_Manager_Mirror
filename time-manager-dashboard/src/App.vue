<template>
  <RouterView v-if="!user || $route.meta.public" v-slot="{ Component }">
    <component :is="Component" v-if="Component && $route.meta.public" v-bind="publicBindings" />
  </RouterView>

  <div v-else class="shell">
    <a class="skip-link" href="#main-content">Aller au contenu</a>
    <AppSidebar :role="user.role" :theme="theme" :space="persona.space" :user-id="userId" :organization-access="Boolean(organizationSession)" @update:theme="setTheme">
      <AccountIdentity v-if="organizationSession" :session="organizationSession" @logout="logout" />
      <User v-else :user="user" @logout="logout" />
    </AppSidebar>

    <main id="main-content" class="main" tabindex="-1">
      <p v-if="organizationSession" class="demo-notice">Mode démonstration · vos comptes et actions restent dans ce navigateur.</p>
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
import AccountIdentity from './components/auth/AccountIdentity.vue'
import { AUTH_USE_MOCK } from './services/organizationService'
import WorkingTimes from './components/WorkingTimes.vue'
import AppSidebar from './components/layout/AppSidebar.vue'
import OnboardingTour from './components/ui/OnboardingTour.vue'
import { personaFor } from './services/orgService'
import { getWorkingTimes } from './services/workingTimeService'
import { auth, logout, fetchMe, startOrganizationSession } from './stores/auth'
import { durationInHours } from './utils/date'
import { applyTheme, applyStrongText, readStrongText, readStorage, readTheme, writeStorage, writeTheme } from './utils/session'

const OVERLAY_ROUTES = ['workingTimeCreate', 'workingTimeEdit']
const TOUR_KEY = 'tm-tour-seen'

const TOUR_STEPS = [
  { title: 'Pointer, c’est un seul geste', text: 'Touchez le grand rond en arrivant, puis en partant. Le reste se calcule tout seul.' },
  { title: 'Chaque heure a sa couleur', text: 'Jour, nuit ×1,5, astreinte, heures sup. ×2 : la même couleur du planning à la fiche de paie.' },
  { title: 'Une erreur ? Signalez-la', text: 'Complétez un départ oublié ou proposez une correction depuis « Mes heures ». Votre responsable examine votre proposition avant de modifier les horaires.' },
]

export default {
  name: 'App',

  components: { AccountIdentity, AppSidebar, OnboardingTour, RouterView, ToastStack, User, WorkingTimes },

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

    organizationSession() { return auth.organizationSession },

    publicBindings() {
      return AUTH_USE_MOCK ? { theme: this.theme, onLogin: this.loginOrganization, 'onUpdate:theme': this.setTheme } : {}
    },

    userId() {
      return this.user ? this.user.id : null
    },

    // Demo content (planning, payroll...) still comes from the mocks; the
    // identity is the real user's.
    persona() {
      const mock = personaFor(this.user && this.user.role === 'administrator' ? 'admin' : this.user && this.user.role)
      if (!this.user) return mock
      if (this.organizationSession) return { ...mock, username: this.user.username, email: this.user.email, name: `${this.user.first_name} ${this.user.last_name}`, space: this.organizationSession.organization.name }

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
      if (name === 'profile') return { theme: this.theme }
      if (name === 'organization') return { session: this.organizationSession }

      if (name === 'overview') {
        return { persona: this.persona, userId: this.userId, workingTimes: this.workingTimes, loading: this.loadingStats, now: this.now }
      }
      if (name === 'workingTimes') return { week: this.week, username: Number(this.$route.params.userID) === this.userId ? this.persona.username : '' }
      if (name === 'planning' || name === 'payroll' || name === 'team') return { now: this.now }

      return {}
    },

    routeListeners() {
      if (this.$route.name === 'profile') return { 'onUpdate:theme': this.setTheme, onLogout: this.logout, onTour: this.openTour }
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

  created() { applyStrongText(readStrongText()) },

  mounted() {
    window.addEventListener('focus', this.refreshOrganizationSession)
    this.clock = setInterval(() => {
      this.now = new Date()
    }, 60000)
  },

  beforeUnmount() {
    window.removeEventListener('focus', this.refreshOrganizationSession)
    clearInterval(this.clock)
  },

  methods: {
    async refreshOrganizationSession() {
      if (!this.organizationSession) return
      await fetchMe()
      if (!this.user) this.$router.push({ name: 'login' })
      else if (this.$route.meta.roles && !this.$route.meta.roles.includes(this.user.role)) {
        this.$router.push({ name: this.user.role === 'administrator' ? 'organization' : this.user.role === 'manager' ? 'team' : 'overview' })
      }
    },

    loginOrganization(session) {
      startOrganizationSession(session)
      this.$router.push({ name: session.role === 'admin' ? 'organization' : session.role === 'manager' ? 'team' : 'overview' })
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
  grid-template-columns: 224px minmax(0, 1fr);
  min-height: 100vh;
}

.main > .demo-notice { margin-bottom: 20px; }

.main {
  min-width: 0;
  padding: 30px 34px 48px;
}

@media (max-width: 900px) {
  .shell {
    display: block;
  }

  .main {
    padding: 22px 16px calc(98px + env(safe-area-inset-bottom));
  }
}
</style>
