<script setup>
const props = defineProps({
  status: { type: String, required: true }, // online | break | offline
  label: { type: String, required: true },
})
</script>

<template>
  <span class="tag" :class="`tag--${props.status}`">
    <span class="dot" :class="`dot--${props.status}`"></span>
    {{ label }}
  </span>
</template>