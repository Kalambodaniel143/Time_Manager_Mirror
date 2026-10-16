<template>
  <svg
    class="app-icon"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="2"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <circle v-for="(circle, index) in shape.circles" :key="`c${index}`" :cx="circle[0]" :cy="circle[1]" :r="circle[2]" />
    <rect
      v-for="(rect, index) in shape.rects"
      :key="`r${index}`"
      :x="rect[0]"
      :y="rect[1]"
      :width="rect[2]"
      :height="rect[3]"
      :rx="rect[4]"
    />
    <path v-for="(path, index) in shape.paths" :key="`p${index}`" :d="path" />
  </svg>
</template>

<script>
const ICONS = {
  sun: { circles: [[12, 12, 4]], paths: ['M12 2v2', 'M12 20v2', 'm4.93 4.93 1.41 1.41', 'm17.66 17.66 1.41 1.41', 'M2 12h2', 'M20 12h2', 'm6.34 17.66-1.41 1.41', 'm19.07 4.93-1.41 1.41'] },
  moon: { paths: ['M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z'] },
  contrast: { circles: [[12, 12, 10]], paths: ['M12 18a6 6 0 0 0 0-12v12z'] },
  clock: { circles: [[12, 12, 10]], paths: ['M12 6v6l4 2'] },
  calendar: { rects: [[3, 4, 18, 18, 2]], paths: ['M16 2v4', 'M8 2v4', 'M3 10h18'] },
  users: { circles: [[9, 7, 4]], paths: ['M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2', 'M22 21v-2a4 4 0 0 0-3-3.87', 'M16 3.13a4 4 0 0 1 0 7.75'] },
  shield: { paths: ['M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z', 'm9 12 2 2 4-4'] },
  check: { paths: ['M20 6 9 17l-5-5'] },
  'check-circle': { circles: [[12, 12, 10]], paths: ['m9 12 2 2 4-4'] },
  eye: { circles: [[12, 12, 3]], paths: ['M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z'] },
  'eye-off': { paths: ['M9.88 9.88a3 3 0 1 0 4.24 4.24', 'M10.73 5.08A10.4 10.4 0 0 1 12 5c7 0 10 7 10 7a13 13 0 0 1-1.67 2.68', 'M6.61 6.61A13.5 13.5 0 0 0 2 12s3 7 10 7a9.7 9.7 0 0 0 5.39-1.61', 'm2 2 20 20'] },
  warning: { paths: ['m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z', 'M12 9v4', 'M12 17h.01'] },
  alert: { circles: [[12, 12, 10]], paths: ['M12 8v4', 'M12 16h.01'] },
  info: { circles: [[12, 12, 10]], paths: ['M12 16v-4', 'M12 8h.01'] },
  login: { paths: ['M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4', 'm10 17 5-5-5-5', 'M15 12H3'] },
  logout: { paths: ['M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4', 'm16 17 5-5-5-5', 'M21 12H9'] },
  siren: { paths: ['M7 18v-6a5 5 0 1 1 10 0v6', 'M5 21a1 1 0 0 1-1-1v-1a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v1a1 1 0 0 1-1 1z', 'M21 12h1', 'M18.5 4.5 18 5', 'M2 12h1', 'M12 2v1', 'm4.93 4.93.71.71'] },
  alarm: { circles: [[12, 13, 8]], paths: ['M12 9v4l2 2', 'M5 3 2 6', 'm22 6-3-3', 'M6.38 18.7 4 21', 'M17.64 18.67 20 21'] },
  rotate: { paths: ['M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8', 'M3 3v5h5'] },
  palm: { paths: ['M13 8c0-2.76-2.46-5-5.5-5S2 5.24 2 8h2l1-1 1 1h4', 'M13 7.14A5.82 5.82 0 0 1 16.5 6c3.04 0 5.5 2.24 5.5 5h-3l-1-1-1 1h-3', 'M5.89 9.71c-2.15 2.15-2.3 5.47-.35 7.43l4.24-4.25.7-.7.71-.71 2.12-2.12c-1.95-1.96-5.27-1.8-7.42.35', 'M11 15.5c.5 2.5-.17 4.5-1 6.5h4c2-5.5-.5-12-1-14'] },
  coffee: { paths: ['M17 8h1a4 4 0 1 1 0 8h-1', 'M3 8h14v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4Z', 'M6 2v2', 'M10 2v2', 'M14 2v2'] },
  phone: { rects: [[5, 2, 14, 20, 2]], paths: ['M12 18h.01'] },
  help: { circles: [[12, 12, 10]], paths: ['M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3', 'M12 17h.01'] },
  message: { paths: ['M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z', 'M7 8h10', 'M7 12h6'] },
  'chevron-left': { paths: ['m15 18-6-6 6-6'] },
  'chevron-right': { paths: ['m9 18 6-6-6-6'] },
  close: { paths: ['M18 6 6 18', 'm6 6 12 12'] },
  wrench: { paths: ['M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z'] },
}

export default {
  name: 'AppIcon',

  props: {
    name: { type: String, required: true },
  },

  computed: {
    shape() {
      const icon = ICONS[this.name] || ICONS.info
      return { circles: icon.circles || [], rects: icon.rects || [], paths: icon.paths || [] }
    },
  },
}
</script>

<style scoped>
.app-icon {
  width: 1em;
  height: 1em;
  flex-shrink: 0;
}
</style>
