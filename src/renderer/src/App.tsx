import React, { useEffect, useState, useCallback } from 'react'
import { MenuBar } from './components/Menu/MenuBar'
import { MDIContainer } from './components/MDI/MDIContainer'
import { DialogManager } from './components/Dialogs/DialogManager'
import { QuickSearchOverlay } from './components/QuickSearch/QuickSearchOverlay'
import { useProgramStore } from './store/programStore'
import { useUIStore } from './store/uiStore'
import { useMDIStore } from './store/mdiStore'

const App: React.FC = () => {
  const loadData = useProgramStore((state) => state.loadData)
  const settings = useProgramStore((state) => state.settings)
  const groups = useProgramStore((state) => state.groups)
  const deleteItem = useProgramStore((state) => state.deleteItem)
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const toggleQuickSearch = useUIStore((state) => state.toggleQuickSearch)
  const activeDialog = useUIStore((state) => state.activeDialog)
  const activeMenu = useUIStore((state) => state.activeMenu)
  const setActiveMenu = useUIStore((state) => state.setActiveMenu)
  const selectedItemId = useUIStore((state) => state.selectedItemId)
  const selectedGroupId = useUIStore((state) => state.selectedGroupId)
  const openDialog = useUIStore((state) => state.openDialog)
  const cascadeWindows = useMDIStore((state) => state.cascadeWindows)
  const tileWindows = useMDIStore((state) => state.tileWindows)

  const [platform, setPlatform] = useState<string>('linux')
  const [shortcutHintDismissed, setShortcutHintDismissed] = useState(
    () => localStorage.getItem('quickSearchHintDismissed') === 'true'
  )

  // Load data and platform on mount
  useEffect(() => {
    loadData()
    window.electronAPI.system.getPlatform().then(setPlatform)

    // Show welcome dialog on first run
    if (!localStorage.getItem('hasLaunched')) {
      localStorage.setItem('hasLaunched', 'true')
      openDialog('welcome')
    }
  }, [loadData])

  useEffect(() => {
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
  }, [settings.groupChromeScale])

  useEffect(() => {
    const root = document.documentElement
    root.classList.toggle('theme-dark', settings.theme === 'dark')
  }, [settings.theme])

  // Listen for quick search toggle from main process
  useEffect(() => {
    const handleToggle = () => {
      toggleQuickSearch()
      if (!shortcutHintDismissed) {
        setShortcutHintDismissed(true)
        localStorage.setItem('quickSearchHintDismissed', 'true')
      }
    }

    window.electronAPI.on('quick-search:toggle', handleToggle)

    return () => {
      window.electronAPI.off('quick-search:toggle', handleToggle)
    }
  }, [toggleQuickSearch, shortcutHintDismissed])

  // Launch selected item helper
  const launchSelectedItem = useCallback(async () => {
    if (!selectedItemId || !selectedGroupId) return
    const group = groups.find((g) => g.id === selectedGroupId)
    const item = group?.items.find((i) => i.id === selectedItemId)
    if (!item) return

    try {
      const result = await window.electronAPI.program.launch(item)
      if (!result.success) {
        console.error('Failed to launch program:', result.error)
      }
      if (settings.minimizeOnUse) {
        window.electronAPI.window.minimize()
      }
    } catch (error) {
      console.error('Failed to launch program:', error)
    }
  }, [selectedItemId, selectedGroupId, groups, settings.minimizeOnUse])

  // Global keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      // Skip if a dialog is open
      if (activeDialog !== null) return
      // Skip if quick search is open (it has its own keyboard handling)
      if (quickSearchOpen) return

      // Skip Alt shortcuts if an input/textarea is focused
      const activeEl = document.activeElement
      const isInputFocused =
        activeEl instanceof HTMLInputElement ||
        activeEl instanceof HTMLTextAreaElement ||
        activeEl instanceof HTMLSelectElement

      // Alt+key menu shortcuts
      if (event.altKey && !event.ctrlKey && !event.metaKey && !isInputFocused) {
        switch (event.key.toLowerCase()) {
          case 'f':
            event.preventDefault()
            setActiveMenu(activeMenu === 'File' ? null : 'File')
            return
          case 'o':
            event.preventDefault()
            setActiveMenu(activeMenu === 'Options' ? null : 'Options')
            return
          case 'w':
            event.preventDefault()
            setActiveMenu(activeMenu === 'Window' ? null : 'Window')
            return
          case 'h':
            event.preventDefault()
            setActiveMenu(activeMenu === 'Help' ? null : 'Help')
            return
        }
      }

      // Shift+F4 → tile windows
      if (event.key === 'F4' && event.shiftKey && !event.ctrlKey && !event.altKey) {
        event.preventDefault()
        tileWindows()
        return
      }

      // Shift+F5 → cascade windows
      if (event.key === 'F5' && event.shiftKey && !event.ctrlKey && !event.altKey) {
        event.preventDefault()
        cascadeWindows()
        return
      }

      // Escape → close menu if open
      if (event.key === 'Escape' && activeMenu !== null) {
        event.preventDefault()
        setActiveMenu(null)
        return
      }

      // Enter → launch selected item (if no menu open)
      if (event.key === 'Enter' && !isInputFocused && activeMenu === null) {
        if (selectedItemId && selectedGroupId) {
          event.preventDefault()
          launchSelectedItem()
          return
        }
      }

      // Delete → confirm delete selected item
      if (event.key === 'Delete' && !isInputFocused && activeMenu === null) {
        if (selectedItemId && selectedGroupId) {
          const group = groups.find((g) => g.id === selectedGroupId)
          const item = group?.items.find((i) => i.id === selectedItemId)
          if (item) {
            event.preventDefault()
            openDialog('confirm', {
              confirmOptions: {
                title: 'Delete Program Item',
                message: `Are you sure you want to delete "${item.name}"?`,
                onConfirm: () => deleteItem(selectedGroupId, selectedItemId)
              }
            })
          }
        }
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [
    activeDialog,
    quickSearchOpen,
    activeMenu,
    setActiveMenu,
    tileWindows,
    cascadeWindows,
    selectedItemId,
    selectedGroupId,
    groups,
    launchSelectedItem,
    openDialog,
    deleteItem
  ])

  const modKey = platform === 'darwin' ? 'Cmd' : 'Ctrl'

  return (
    <div className="app">
      <MenuBar platform={platform} />
      <MDIContainer />
      <DialogManager />
      {quickSearchOpen && <QuickSearchOverlay />}
      {!shortcutHintDismissed && (
        <div className="shortcut-hint">
          Press {modKey}+Shift+Space for Quick Search
        </div>
      )}
    </div>
  )
}

export default App
