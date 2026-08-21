<template>
  <span class="tag" :class="`tag--${status}`">
    <span class="dot" :class="`dot--${status}`"></span>
    {{ label }}
  </span>
</template>

<script>
export default {
  name: 'StatusBadge',
  props: {
    status: { type: String, required: true }, // online | break | offline
    label: { type: String, required: true }
  }
}
</script>
