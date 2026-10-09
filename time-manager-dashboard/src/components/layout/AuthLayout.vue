<template>
  <div class="login">
    <div class="auth-theme-controls"><ThemeToggle :model-value="theme" @update:model-value="setTheme" /></div>
    <section class="intro">
      <span class="deco deco-a" aria-hidden="true"></span>
      <span class="deco deco-b" aria-hidden="true"></span>

      <div class="intro-body">
        <h1 class="intro-title">Time Manager</h1>
        <p class="intro-eyebrow">Votre organisation</p>
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



        <InfoNote icon="phone" title="Pas d’ordinateur ?">
          Utilisez un téléphone ou un appareil partagé. Si vous avez besoin d’aide, demandez un accompagnement à votre responsable.
        </InfoNote>
      </div>
    </section>
  </div>
</template>

<script>
import ThemeToggle from '../ui/ThemeToggle.vue'
import AppIcon from '../ui/AppIcon.vue'
import InfoNote from '../ui/InfoNote.vue'
import { applyTheme, readTheme, writeTheme } from '../../utils/session'

const POINTS = [
  { icon: 'login', text: 'Un geste pour pointer, sur ordinateur ou téléphone.' },
  { icon: 'moon', text: 'Vos nuits comptent ×1,5, vos heures sup. ×2, et vous le voyez.' },
  { icon: 'eye', text: 'Vous voyez tout ce que voit votre manager. Rien d’autre n’est enregistré.' },
]



const PIXELS = 'llllddllllllolllddllo'.split('').map((code) => ({ l: 'light', d: 'dark', o: 'orange' })[code])

// Shared layout of the public pages (login, registration): presentation on the
// left, the page's form in the default slot, then the display settings.
export default {
  name: 'AuthLayout',

  components: { ThemeToggle, AppIcon, InfoNote },

  data() {
    return {
      theme: readTheme(),
      points: POINTS,
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

}

.deco, .pixels { display: none; }
.intro-title { font-family: var(--font); font-size: clamp(32px, 3vw, 48px); font-weight: 700; text-transform: none; letter-spacing: -.04em; }
.intro-title::after, .intro-eyebrow::before, .intro-eyebrow::after { content: none; }
.intro-eyebrow { margin-top: 24px; text-transform: none; }
.intro-list { font-size: 16px; }
.login { grid-template-columns: minmax(280px, 34%) minmax(0, 1fr); }
.panel { justify-content: center; padding: 48px 28px; }
.form { margin: 0; width: min(500px, 100%); }
@media (max-width: 760px) {
 .login { display: block; }
 .intro { display: flex; min-height: auto; padding: 28px 20px; align-items: center; text-align: center; }
 .intro-title { font-size: 28px; }
 .intro-eyebrow { margin: 8px 0 0; }
 .intro-list { display: none; }
 .panel { padding: 28px 20px; }
}

.login { position: relative; }
.auth-theme-controls { position: absolute; z-index: 1; top: 16px; right: 20px; }
@media (max-width: 760px) { .auth-theme-controls { position: static; display: flex; justify-content: flex-end; padding: 12px 16px; background: var(--bg); } }
</style>
