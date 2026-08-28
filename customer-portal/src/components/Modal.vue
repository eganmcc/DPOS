<script setup lang="ts">
defineProps<{ open: boolean; title?: string; wide?: boolean }>();
const emit = defineEmits<{ close: [] }>();
</script>

<template>
  <Teleport to="body">
    <div v-if="open" class="overlay" @click.self="emit('close')">
      <div class="modal" :class="{ wide }">
        <div class="modal-head">
          <h3>{{ title }}</h3>
          <button class="x" @click="emit('close')" aria-label="Close">&times;</button>
        </div>
        <div class="modal-body">
          <slot />
        </div>
        <div class="modal-foot" v-if="$slots.footer">
          <slot name="footer" />
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  background: rgba(11, 32, 54, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
  padding: 20px;
}
.modal {
  background: var(--surface);
  border-radius: var(--radius-panel);
  box-shadow: var(--shadow-e3);
  width: 100%;
  max-width: 440px;
  max-height: 90vh;
  overflow: auto;
}
.modal.wide {
  max-width: 640px;
}
.modal-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 18px 20px 8px;
}
.modal-head h3 {
  font-size: 18px;
}
.x {
  border: none;
  background: transparent;
  font-size: 26px;
  line-height: 1;
  cursor: pointer;
  color: var(--on-surface-variant);
}
.modal-body {
  padding: 8px 20px 12px;
}
.modal-foot {
  padding: 8px 20px 20px;
  display: flex;
  gap: 10px;
  justify-content: flex-end;
}
</style>
