import React, { useEffect, useState, useCallback, useRef } from 'react'
import { DialogManager } from './components/Dialogs/DialogManager'
import { LaunchFeedback } from './components/LaunchFeedback'
import { QuickSearchOverlay } from './components/QuickSearch/QuickSearchOverlay'
import { useProgramStore } from './store/programStore'
import { useUIStore } from './store/uiStore'
import { useSounds } from './hooks/useSounds'
import { suspendSoundContext } from './utils/sounds'
import { getShell } from './shells'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import { LauncherTools } from './components/LauncherTools/LauncherTools'

const App: React.FC = () => {
  const isLauncherTools = new URLSearchParams(window.location.search).has('launcherTools')
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
  const launchFeedbackStatus = useUIStore((state) => state.launchFeedback.status)

  const sounds = useSounds()
  const [platform, setPlatform] = useState<string>('linux')
  const startupTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const startupScheduledRef = useRef(false)

  // Load data and platform on mount. All delayed work is canceled on teardown.
  useEffect(() => {
    let cancelled = false

    void loadData().then(() => {
      if (cancelled) return

      if (!localStorage.getItem('hasLaunched')) {
        localStorage.setItem('hasLaunched', 'true')
        // Keep the canonical Program Manager workspace unobscured. Win95
        // retains the launcher onboarding that existed before shell separation.
        if (useProgramStore.getState().settings.shell === 'win95') openDialog('welcome')
      }

      if (startupScheduledRef.current) return
      startupScheduledRef.current = true
      startupTimerRef.current = setTimeout(() => {
        startupTimerRef.current = null
        sounds.startupChime()
      }, 300)
    })
    void window.electronAPI.system.getPlatform().then((nextPlatform) => {
      if (!cancelled) setPlatform(nextPlatform)
    })

    return () => {
      cancelled = true
      if (startupTimerRef.current !== null) {
        clearTimeout(startupTimerRef.current)
        startupTimerRef.current = null
      }
      startupScheduledRef.current = false
      suspendSoundContext()
    }
  }, [loadData, sounds, openDialog])

  useEffect(() => {
    const root = document.documentElement
    // WfW Program Manager has one canonical system palette. Keep the optional
    // dark launcher theme confined to the Win95 presentation.
    root.classList.toggle('theme-dark', settings.theme === 'dark' && settings.shell === 'win95')
  }, [settings.shell, settings.theme])

  useEffect(() => {
    document.title = isLauncherTools ? 'Launcher Tools' : settings.shell === 'win95' ? 'Gosh 95' : 'Program Manager'
  }, [isLauncherTools, settings.shell])

  useEffect(() => {
    const openToolsShortcut = (event: KeyboardEvent): void => {
      if (event.ctrlKey && event.altKey && event.key.toLowerCase() === 't') {
        event.preventDefault()
        void window.electronAPI.app.openLauncherTools()
      }
    }
    window.addEventListener('keydown', openToolsShortcut)
    return () => window.removeEventListener('keydown', openToolsShortcut)
  }, [])

  // Listen for quick search toggle from main process
  useEffect(() => {
    const handleToggle = (): void => {
      toggleQuickSearch()
    }

    window.electronAPI.on(IPC_CHANNELS.QUICK_SEARCH_TOGGLE, handleToggle)

    return () => {
      window.electronAPI.off(IPC_CHANNELS.QUICK_SEARCH_TOGGLE, handleToggle)
    }
  }, [toggleQuickSearch])

  useEffect(() => {
    const handleStoreChanged = (): void => { void loadData() }
    window.electronAPI.on(IPC_CHANNELS.STORE_CHANGED, handleStoreChanged)
    return () => window.electronAPI.off(IPC_CHANNELS.STORE_CHANGED, handleStoreChanged)
  }, [loadData])

  useEffect(() => {
    const openLauncherTools = (): void => openDialog('settings')
    window.electronAPI.on(IPC_CHANNELS.APP_OPEN_LAUNCHER_TOOLS, openLauncherTools)
    return () => window.electronAPI.off(IPC_CHANNELS.APP_OPEN_LAUNCHER_TOOLS, openLauncherTools)
  }, [openDialog])

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
      // Win31 owns period-specific Delete/Enter/menu semantics inside its shell.
      if (settings.shell === 'win31') return

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
    deleteItem,
    settings.shell
  ])

  if (isLauncherTools) return <LauncherTools />

  // Resolve active shell
  const shellDef = getShell(settings.shell ?? 'win31')
  const ShellComponent = shellDef?.component

  return (
    <div
      className={`app shell-${settings.shell ?? 'win31'} ${launchFeedbackStatus === 'launching' ? 'app-launching' : ''}`}
    >
      {ShellComponent && <ShellComponent platform={platform} />}
      {settings.shell === 'win95' && <LaunchFeedback />}
      <DialogManager />
      {quickSearchOpen && <QuickSearchOverlay />}
    </div>
  )
}

export default App
