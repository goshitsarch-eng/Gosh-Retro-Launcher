<script lang="ts">
  import type { Snippet } from 'svelte'

  interface Props {
    title: string
    onClose: () => void
    children: Snippet
    width?: number
  }

  let { title, onClose, children, width = 400 }: Props = $props()

  // Handle escape key to close
  $effect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        onClose()
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  })

  // Prevent clicks inside dialog from closing it
  function handleDialogClick(event: MouseEvent) {
    event.stopPropagation()
  }
</script>

<div class="win31-dialog-overlay" onclick={onClose} role="dialog" aria-modal="true">
  <div
    class="win31-dialog"
    style="width: {width}px"
    onclick={handleDialogClick}
    role="document"
  >
    <div class="win31-titlebar">
      <span class="win31-titlebar-text">{title}</span>
    </div>
    <div class="win31-dialog-content">
      {@render children()}
    </div>
  </div>
</div>
