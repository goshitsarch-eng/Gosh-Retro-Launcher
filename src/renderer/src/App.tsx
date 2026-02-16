import React, { useEffect, useState, useCallback, useRef } from 'react'
import { DialogManager } from './components/Dialogs/DialogManager'
import { QuickSearchOverlay } from './components/QuickSearch/QuickSearchOverlay'
import { useProgramStore } from './store/programStore'
import { useUIStore } from './store/uiStore'
import { useSounds } from './hooks/useSounds'
import { getShell } from './shells'

const App: React.FC = () => {
  const loadData = useProgramStore((state) => state.loadData)
  const settings = useProgramStore((state) => state.settings)
  const groups = useProgramStore((state) => state.groups)
  const deleteItem = useProgramStore((state) => state.deleteItem)
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const toggleQuickSearch = useUIStore((state) => state.toggleQuickSearch)
  const activeDialog = useUIStore((state) => state.activeDialog)
  const activeMenu = useUIStore((state) => state.activeMenu)
  const selectedItemId = useUIStore((state) => state.selectedItemId)
  const selectedGroupId = useUIStore((state) => state.selectedGroupId)
  const openDialog = useUIStore((state) => state.openDialog)

  const sounds = useSounds()
  const [platform, setPlatform] = useState<string>('linux')
  const initializedRef = useRef(false)

  // Load data and platform on mount
  useEffect(() => {
    if (initializedRef.current) {
      return
    }
    initializedRef.current = true

    loadData().then(() => {
      setTimeout(() => sounds.startupChime(), 300)
    })
    window.electronAPI.system.getPlatform().then(setPlatform)

    // Show welcome dialog on first run
    if (!localStorage.getItem('hasLaunched')) {
      localStorage.setItem('hasLaunched', 'true')
      openDialog('welcome')
    }
  }, [loadData, sounds, openDialog])

  useEffect(() => {
    const root = document.documentElement
    root.classList.toggle('theme-dark', settings.theme === 'dark')
  }, [settings.theme])

  // Listen for quick search toggle from main process
  useEffect(() => {
    const handleToggle = (): void => {
      toggleQuickSearch()
    }

    window.electronAPI.on('quick-search:toggle', handleToggle)

    return () => {
      window.electronAPI.off('quick-search:toggle', handleToggle)
    }
  }, [toggleQuickSearch])

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

  // Shared keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      // Skip if a dialog is open
      if (activeDialog !== null) return
      // Skip if quick search is open (it has its own keyboard handling)
      if (quickSearchOpen) return

      // Skip if an input/textarea is focused
      const activeEl = document.activeElement
      const isInputFocused =
        activeEl instanceof HTMLInputElement ||
        activeEl instanceof HTMLTextAreaElement ||
        activeEl instanceof HTMLSelectElement

      // Enter -> launch selected item (if no menu open)
      if (event.key === 'Enter' && !isInputFocused && activeMenu === null) {
        if (selectedItemId && selectedGroupId) {
          event.preventDefault()
          launchSelectedItem()
          return
        }
      }

      // Delete -> confirm delete selected item
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
    selectedItemId,
    selectedGroupId,
    groups,
    launchSelectedItem,
    openDialog,
    deleteItem
  ])

  // Resolve active shell
  const shellDef = getShell(settings.shell ?? 'win31')
  const ShellComponent = shellDef?.component

  return (
    <div className={`app shell-${settings.shell ?? 'win31'}`}>
      {ShellComponent && <ShellComponent platform={platform} />}
      <DialogManager />
      {quickSearchOpen && <QuickSearchOverlay />}
    </div>
  )
}

export default App
