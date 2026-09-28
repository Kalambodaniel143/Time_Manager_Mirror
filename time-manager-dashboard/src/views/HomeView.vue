<script setup>
import { ref, onMounted } from 'vue'

const status = ref('checking...')

onMounted(async () => {
  try {
    const res = await fetch('/api/users')
    status.value = res.ok ? 'Backend reachable' : `Backend responded ${res.status}`
  } catch {
    status.value = 'Backend unreachable'
  }
})
</script>

<template>
  <main>
    <h1>Time Manager Dashboard</h1>
    <p>API status: {{ status }}</p>
  </main>
</template>
