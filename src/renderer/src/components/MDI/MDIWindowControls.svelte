<script lang="ts">
  import Button from '../Common/Button.svelte'

  interface Props {
    onMinimize: () => void
    onMaximize: () => void
    onClose: () => void
    isMaximized: boolean
  }

  let { onMinimize, onMaximize, onClose, isMaximized }: Props = $props()

  function handleMinimize(e: MouseEvent) {
    e.stopPropagation()
    onMinimize()
  }

  function handleMaximize(e: MouseEvent) {
    e.stopPropagation()
    onMaximize()
  }
</script>

<div class="win31-titlebar-controls">
  <Button
    small
    onclick={handleMinimize}
    title="Minimize"
  >
    {#snippet children()}▼{/snippet}
  </Button>
  <Button
    small
    onclick={handleMaximize}
    title={isMaximized ? 'Restore' : 'Maximize'}
  >
    {#snippet children()}{isMaximized ? '◇' : '▲'}{/snippet}
  </Button>
</div>
