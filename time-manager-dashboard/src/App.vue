<template>
  <RouterView v-if="!user || ($route.meta.public && !$route.meta.help)" v-slot="{ Component }">
    <component :is="Component" v-if="Component && $route.meta.public" v-bind="publicBindings" />
  </RouterView>

  <div v-else class="shell">
    <a class="skip-link" href="#main-content">{{ $t("Aller au contenu") }}</a>
    <AppSidebar :role="user.role" :theme="theme" :space="persona.space" :user-id="userId" :organization-access="Boolean(citySession)" :demo="Boolean(organizationSession)" @update:theme="setTheme">
      <AccountIdentity v-if="organizationSession" :session="organizationSession" @logout="logout" />
      <User v-else :user="user" @logout="logout" />
    </AppSidebar>

    <main id="main-content" class="main" tabindex="-1">
      <p v-if="organizationSession" class="demo-notice">{{ $t("Mode démonstration · vos comptes et actions restent dans ce navigateur.") }}</p>
      <SpeechControls />
      <p v-if="workforceError" class="field-error" role="alert">{{ $t(workforceError) }}</p>
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
        <component :is="Component" v-if="Component" :ref="routeRef" :key="`${userId}:${$route.path}`" v-bind="routeBindings" />
      </RouterView>
    </main>

    <OnboardingTour v-if="tourOpen" :steps="tourSteps" @close="closeTour" />
  </div>

  <ToastStack />
</template>

<script>
import { RouterView } from 'vue-router'
import { setLocale } from './utils/i18n'
import ToastStack from './components/ToastStack.vue'
import User from './components/User.vue'
import AccountIdentity from './components/auth/AccountIdentity.vue'
import WorkingTimes from './components/WorkingTimes.vue'
import AppSidebar from './components/layout/AppSidebar.vue'
import OnboardingTour from './components/ui/OnboardingTour.vue'
import { personaFor } from './services/orgService'
import { getWorkingTimes } from './services/workingTimeService'
import { listenForSessionChanges } from './utils/sessionEvents'
import { auth, logout, clearSession, fetchMe, startOrganizationSession } from './stores/auth'
import { notify } from './utils/toast'
import SpeechControls from './components/workforce/SpeechControls.vue'
import { loadContext, savePreferences, clearWorkforce, workforce, refreshNotificationCount } from './services/workforceService'
import { stopReading } from './utils/speech'
import { durationInHours } from './utils/date'
import { displayName } from './utils/people'
import { applyTheme, applyStrongText, readStrongText, readStorage, readTheme, writeStorage, writeTheme } from './utils/session'

const OVERLAY_ROUTES = ['workingTimeCreate', 'workingTimeEdit']
const TOUR_KEY = 'tm-tour-seen'

const TOUR_STEPS = [
  { title: 'Pointer, c’est un seul geste', text: 'Touchez le grand rond en arrivant, puis en partant. Le reste se calcule tout seul.' },
  { title: 'Retrouvez vos horaires', text: 'Consultez les arrivées, départs et durées enregistrés dans « Mes heures ».' },
  { title: 'Une erreur ? Signalez-la', text: 'Complétez un départ oublié depuis « Mes heures ». Proposez une correction depuis « Mes heures ». Votre responsable examine la demande avant de modifier les horaires.' },
]

export default {
  name: 'App',

  components: { SpeechControls, AccountIdentity, AppSidebar, OnboardingTour, RouterView, ToastStack, User, WorkingTimes },

  data() {
    return {
      theme: 'light',
      workingTimes: [],
      loadingStats: false,
      statsError: '',
      statsVersion: 0,
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

    workforceError() { return workforce.error },
    organizationSession() { return auth.organizationSession },

    citySession() { return auth.organizationSession || (auth.organization ? { organization: auth.organization, user: auth.user, role: auth.user?.role === 'administrator' ? 'admin' : auth.user?.role } : null) },

    publicBindings() {
      if (this.$route.meta.help) return { standalone: true, theme: this.theme, 'onUpdate:theme': this.setTheme }
      return { theme: this.theme, onLogin: this.loginOrganization, 'onUpdate:theme': this.setTheme }
    },

    userId() {
      return this.user ? this.user.id : null
    },

    persona() {
      const mock = personaFor(this.user && this.user.role === 'administrator' ? 'admin' : this.user && this.user.role)
      if (!this.user) return mock
      if (this.organizationSession) return { ...mock, username: this.user.username, email: this.user.email, name: `${this.user.first_name} ${this.user.last_name}`, space: this.organizationSession.organization.name }

      return { ...mock, username: this.user.username, email: this.user.email, name: displayName(this.user), space: auth.organization?.name || 'Mon espace' }
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
      if (name === 'organization') return { session: this.citySession }

      if (name === 'overview') {
        return { persona: this.persona, userId: this.userId, workingTimes: this.workingTimes, loading: this.loadingStats, error: this.statsError, now: this.now }
      }
      if (name === 'workingTimes') return { week: this.week, username: Number(this.$route.params.userID) === this.userId ? this.persona.username : '' }
      if (name === 'planning' || name === 'payroll' || name === 'team') return { now: this.now }

      return {}
    },

    routeListeners() {
      if (this.$route.name === 'profile') return { 'onUpdate:theme': this.setTheme, onLogout: this.logout, onTour: this.openTour, onDeleted: this.onAccountDeleted }
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
      handler(id, previous) {
        if (id !== previous) {
          clearWorkforce(); stopReading(); this.workingTimes = []; this.currentUser = null
        }
        this.loadStats()
        this.refreshNotificationBadge()
        // The theme may have been picked on the login page.
        this.setTheme(readTheme(), false)
        if (!id) { clearWorkforce(); stopReading() }
        else if (!this.organizationSession) this.loadPreferences(id)
        this.tourOpen = Boolean(id) && this.user.role === 'employee' && !readStorage(TOUR_KEY)
      },
    },
  },

  created() { applyStrongText(readStrongText()) },

  mounted() {
    this.stopSessionSync = listenForSessionChanges(this.refreshOrganizationSession)
    window.addEventListener('focus', this.refreshOrganizationSession)
    this.notificationsClock = setInterval(this.refreshNotificationBadge, 30000)
    this.clock = setInterval(() => {
      this.now = new Date()
    }, 60000)
  },

  beforeUnmount() {
    this.stopSessionSync?.()
    window.removeEventListener('focus', this.refreshOrganizationSession)
    clearInterval(this.clock)
    clearInterval(this.notificationsClock)
  },

  methods: {
    async refreshNotificationBadge() { if (!this.userId || this.organizationSession || document.hidden) return; try { await refreshNotificationCount() } catch { /* The Notifications page exposes load errors and provides retry. */ } },
    async loadPreferences(id) {
      try { const context = await loadContext(); if (this.userId !== id) return; this.setTheme(context.preferences.theme, false); if (context.preferences.language) setLocale(context.preferences.language); applyStrongText(context.preferences.strong_text); this.tourOpen = this.user.role === 'employee' && !context.preferences.tour_seen }
      catch { /* The page displays workforce.error; existing account actions stay usable. */ }
    },
    async refreshOrganizationSession() {
      if (this.organizationSession) return
      const previousId = this.user?.id
      try { await fetchMe({ throwOnFailure: true }) }
      catch (error) { notify(error.message, 'error'); return }
      if (previousId && this.user && previousId !== this.user.id) {
        notify('Le compte connecté a changé dans un autre onglet. Vérifiez le compte affiché avant de reprendre cette action.', 'error')
        this.$router.push({ name: this.user.role === 'administrator' ? (this.citySession ? 'organization' : 'adminUsers') : this.user.role === 'manager' ? 'team' : 'overview' })
        return
      }
      this.refreshNotificationBadge()
      if (!this.user) { if (!this.$route.meta.public) this.$router.push({ name: 'login' }) }
      else if ((this.$route.meta.public && !this.$route.meta.help) || (this.$route.meta.roles && !this.$route.meta.roles.includes(this.user.role))) {
        this.$router.push({ name: this.user.role === 'administrator' ? (this.citySession ? 'organization' : 'adminUsers') : this.user.role === 'manager' ? 'team' : 'overview' })
      }
    },

    loginOrganization(session) {
      startOrganizationSession(session)
      const redirect = this.$route.query.redirect
      if (typeof redirect === 'string' && /^\/(?!\/)/.test(redirect)) this.$router.push(redirect)
      else this.$router.push({ name: session.role === 'admin' ? (session.organization ? 'organization' : 'adminUsers') : session.role === 'manager' ? 'team' : 'overview' })
    },

    sumHours(entries) {
      return entries.reduce((sum, entry) => sum + durationInHours(entry.start, entry.end), 0)
    },

    async loadStats() {
      const version = this.statsVersion = (this.statsVersion || 0) + 1
      const userId = this.userId
      this.statsError = ''
      if (!this.userId) {
        this.workingTimes = []
        this.loadingStats = false
        return
      }

      this.loadingStats = true

      try {
        const entries = (await getWorkingTimes(userId)) || []
        if (version === this.statsVersion && userId === this.userId) this.workingTimes = entries
      } catch (error) {
        if (version === this.statsVersion) { this.workingTimes = []; this.statsError = error.message }
      } finally {
        if (version === this.statsVersion) this.loadingStats = false
      }
    },

    async onPeriodsChanged() {
      await this.loadStats()
      if (this.$refs.list) await this.$refs.list.getWorkingTimes()
    },

    setTheme(theme, sync = true) {
      this.theme = theme
      applyTheme(theme)
      writeTheme(theme)
      if (sync && this.user && !this.organizationSession) savePreferences({ theme }).catch(error => notify(error.message, 'error'))
    },

    onAccountDeleted() {
      this.statsVersion += 1
      this.tourOpen = false
      this.workingTimes = []
      this.loadingStats = false
      clearSession()
      notify('Votre compte a été supprimé.')
      this.$router.replace({ name: 'login' })
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
      stopReading()
      if (this.user && !this.organizationSession) savePreferences({ tour_seen: true }).catch(error => notify(error.message, 'error'))
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
