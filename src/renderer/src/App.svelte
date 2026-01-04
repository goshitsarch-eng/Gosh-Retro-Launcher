<script lang="ts">
  import MenuBar from './components/Menu/MenuBar.svelte'
  import MDIContainer from './components/MDI/MDIContainer.svelte'
  import DialogManager from './components/Dialogs/DialogManager.svelte'
  import QuickSearchOverlay from './components/QuickSearch/QuickSearchOverlay.svelte'
  import { programStore, uiStore } from './stores'

  let settings = $derived(programStore.settings)
  let quickSearchOpen = $derived(uiStore.quickSearchOpen)

  // Load data on mount
  $effect(() => {
    programStore.loadData()
  })

  // Update MDI chrome scale CSS variables
  $effect(() => {
    const scale = settings.groupChromeScale ?? 1
    const root = document.documentElement.style
    const titlebarHeight = Math.round(22 * scale)
    const controlButtonSize = Math.round(14 * scale)
    const titleFontSize = Math.round(14 * scale)
    const controlButtonFontSize = Math.max(8, Math.round(controlButtonSize * 0.6))
    const borderWidth = Math.max(1, Math.round(1 * scale))

    root.setProperty('--mdi-titlebar-height', `${titlebarHeight}px`)
    root.setProperty('--mdi-control-button-size', `${controlButtonSize}px`)
    root.setProperty('--mdi-control-button-font-size', `${controlButtonFontSize}px`)
    root.setProperty('--mdi-titlebar-font-size', `${titleFontSize}px`)
    root.setProperty('--mdi-border-width', `${borderWidth}px`)
  })

  // Update theme class on document
  $effect(() => {
    const root = document.documentElement
    root.classList.toggle('theme-dark', settings.theme === 'dark')
  })

  // Listen for quick search toggle from main process
  $effect(() => {
    function handleToggle() {
      uiStore.toggleQuickSearch()
    }

    window.electronAPI.on('quick-search:toggle', handleToggle)

    return () => {
      window.electronAPI.off('quick-search:toggle', handleToggle)
    }
  })
</script>

<div class="app">
  <MenuBar />
  <MDIContainer />
  <DialogManager />
  {#if quickSearchOpen}
    <QuickSearchOverlay />
  {/if}
</div>
