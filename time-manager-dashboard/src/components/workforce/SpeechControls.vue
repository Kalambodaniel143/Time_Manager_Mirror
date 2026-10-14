<template><div v-if="enabled" class="speech-controls"><button class="btn btn-outline btn-sm" :disabled="!supported" @click="read">{{ $t("Lire cette page") }}</button><button v-if="speaking" class="btn btn-outline btn-sm" @click="stop">{{ $t("Arrêter la lecture") }}</button><p v-if="error" class="field-hint" role="status">{{ $t(error) }}</p><p v-if="!supported" class="field-hint">{{ $t("La lecture vocale n’est pas disponible dans ce navigateur.") }}</p></div></template>
<script>
import { workforce } from '../../services/workforceService'
import { speech, speechSupported, readAloud, stopReading } from '../../utils/speech'
export default { name: 'SpeechControls', computed: { enabled() { return workforce.preferences.speech_enabled }, supported: speechSupported, speaking() { return speech.speaking }, error() { return speech.error } }, beforeUnmount() { stopReading() }, methods: { read() { readAloud(document.querySelector('#main-content')?.innerText || '') }, stop: stopReading } }
</script>
<style scoped>.speech-controls { display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:20px; }</style>
