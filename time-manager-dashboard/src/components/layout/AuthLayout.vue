<template>
  <div class="login">
    <section class="intro">
      <span class="deco deco-a" aria-hidden="true"></span>
      <span class="deco deco-b" aria-hidden="true"></span>

      <div class="intro-body">
        <h1 class="intro-title">Time Manager</h1>
        <p class="intro-eyebrow">Mairie de Gotham</p>
        <ul class="intro-list">
          <li v-for="point in points" :key="point.icon">
            <AppIcon :name="point.icon" />
            {{ point.text }}
          </li>
        </ul>
      </div>

      <div class="pixels" aria-hidden="true">
        <span v-for="(tone, index) in pixels" :key="index" :class="`pixel-${tone}`"></span>
      </div>
    </section>

    <section class="panel">
      <div class="form">
        <slot />

        <fieldset class="themes">
          <legend class="field-label">Choisissez votre affichage</legend>
          <div class="theme-grid">
            <button
              v-for="option in themes"
              :key="option.value"
              class="theme-card"
              :class="{ 'is-active': option.value === theme }"
              type="button"
              :aria-pressed="option.value === theme"
              @click="setTheme(option.value)"
            >
              <span class="swatch" aria-hidden="true">
                <span v-for="color in option.colors" :key="color" :style="{ background: color }"></span>
              </span>
              <span class="theme-name">{{ option.label }}</span>
              <span class="theme-text">{{ option.text }}</span>
            </button>
          </div>
          <p class="field-hint">Modifiable à tout moment, depuis n’importe quel écran.</p>
        </fieldset>

        <InfoNote icon="phone" title="Pas d’ordinateur ?">
          Pointez depuis votre téléphone, avec votre badge à l’entrepôt, ou auprès de votre chef d’équipe. Formation sur
          place : mardi et jeudi, 7 h – 8 h.
        </InfoNote>
      </div>
    </section>
  </div>
</template>

<script>
import AppIcon from '../ui/AppIcon.vue'
import InfoNote from '../ui/InfoNote.vue'
import { applyTheme, readTheme, writeTheme } from '../../utils/session'

const POINTS = [
  { icon: 'login', text: 'Un geste pour pointer, sur ordinateur, téléphone ou badge.' },
  { icon: 'moon', text: 'Vos nuits comptent ×1,5, vos heures sup. ×2, et vous le voyez.' },
  { icon: 'eye', text: 'Vous voyez tout ce que voit votre manager. Rien d’autre n’est enregistré.' },
]

const THEMES = [
  { value: 'light', label: 'Clair', text: 'La marque, pour le bureau et la journée.', colors: ['#0037ff', '#f2f5ff', '#ffd000'] },
  { value: 'night', label: 'Nuit', text: 'Moins d’éblouissement pour les équipes de nuit.', colors: ['#2c4cf0', '#090d2b', '#c8d0ff'] },
  { value: 'contrast', label: 'Contraste élevé', text: 'Textes renforcés : malvoyance, plein soleil.', colors: ['#0021a5', '#ffffff', '#000000'] },
]

const PIXELS = 'llllddllllllolllddllo'.split('').map((code) => ({ l: 'light', d: 'dark', o: 'orange' })[code])

// Shared layout of the public pages (login, registration): presentation on the
// left, the page's form in the default slot, then the display settings.
export default {
  name: 'AuthLayout',

  components: { AppIcon, InfoNote },

  data() {
    return {
      theme: readTheme(),
      points: POINTS,
      themes: THEMES,
      pixels: PIXELS,
    }
  },

  methods: {
    setTheme(theme) {
      this.theme = theme
      applyTheme(theme)
      writeTheme(theme)
    },
  },
}
</script>

<style scoped>
.login {
  display: grid;
  grid-template-columns: 4fr 5fr;
  min-height: 100vh;
}

.intro {
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 60px 76px;
  overflow: hidden;
  background: var(--side-bg);
  color: #ffffff;
}

.deco {
  position: absolute;
  background: rgba(255, 255, 255, 0.45);
}

.deco-a {
  top: 0;
  right: 0;
  width: 192px;
  height: 100px;
}

.deco-b {
  top: 100px;
  right: 192px;
  width: 100px;
  height: 100px;
}

.intro-title {
  font-family: var(--display);
  font-size: clamp(48px, 6vw, 84px);
  font-weight: 400;
  line-height: 1;
  text-transform: uppercase;
}

.intro-title::after {
  content: '';
  display: inline-block;
  width: 0.32em;
  height: 0.1em;
  margin-left: 0.04em;
  background: var(--orange);
}

.intro-eyebrow {
  margin: 44px 0 26px;
  font-size: 14px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.intro-eyebrow::before {
  content: '< ';
  color: var(--mint);
}

.intro-eyebrow::after {
  content: ' />';
  color: var(--mint);
}

.intro-list {
  display: flex;
  flex-direction: column;
  gap: 18px;
  max-width: 510px;
  padding: 0;
  list-style: none;
  font-size: 18px;
  line-height: 1.5;
}

.intro-list li {
  display: flex;
  gap: 16px;
}

.intro-list svg {
  width: 24px;
  height: 24px;
  margin-top: 2px;
}

.pixels {
  position: absolute;
  bottom: 76px;
  left: 76px;
  display: grid;
  grid-template-columns: repeat(7, 16px);
  gap: 9px;
}

.pixels span {
  width: 16px;
  height: 16px;
}

.pixel-light { background: rgba(255, 255, 255, 0.45); }
.pixel-dark { background: #141c66; }
.pixel-orange { background: var(--orange); }

.panel {
  display: flex;
  align-items: center;
  padding: 60px 16px;
  background: var(--bg);
}

.form {
  display: flex;
  flex-direction: column;
  gap: 22px;
  width: min(542px, 100%);
  margin-left: clamp(0px, 10%, 146px);
}

:slotted(.lede) {
  margin-top: -2px;
  font-size: 16px;
  line-height: 1.6;
  color: var(--text-muted);
}

:slotted(.auth-form) {
  display: flex;
  flex-direction: column;
  gap: 22px;
}

:slotted(.btn-login) {
  padding: 16px 36px;
  font-size: 17px;
}

:slotted(.switch) {
  padding-top: 18px;
  border-top: 1px solid var(--border);
  font-size: 15px;
  color: var(--text-muted);
}

.form :deep(.field-label) {
  font-size: 16px;
  font-weight: 700;
}

.form :deep(.input) {
  padding: 13px 16px;
  font-size: 16px;
}

.themes {
  margin: 0;
  padding: 0;
  border: none;
}

.theme-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 14px;
  margin: 10px 0 10px;
}

.theme-card {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 12px 12px 14px;
  background: var(--surface);
  border: 2px solid var(--input-border);
  border-radius: var(--radius-sm);
  color: var(--text);
  text-align: left;
}

.theme-card.is-active {
  border-color: var(--brand);
  box-shadow: inset 0 0 0 2px var(--brand);
}

.swatch {
  display: grid;
  grid-template-columns: 1fr 2fr 1fr;
  height: 46px;
  margin-bottom: 6px;
  overflow: hidden;
  border: 1px solid var(--border);
  border-radius: 3px;
}

.theme-name {
  font-size: 16px;
  font-weight: 700;
}

.theme-text {
  font-size: 14px;
  line-height: 1.5;
  color: var(--text-muted);
}

@media (max-width: 900px) {
  .login {
    grid-template-columns: 1fr;
  }

  .intro {
    padding: 48px 16px 120px;
  }

  .pixels {
    bottom: 32px;
    left: 16px;
  }

  .deco {
    display: none;
  }

  .form {
    margin: 0 auto;
  }
}

@media (max-width: 560px) {
  .theme-grid {
    grid-template-columns: 1fr;
  }
}
</style>
