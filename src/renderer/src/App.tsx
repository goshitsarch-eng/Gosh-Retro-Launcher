import React, { useEffect, useState, useRef } from 'react'
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
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const toggleQuickSearch = useUIStore((state) => state.toggleQuickSearch)
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

      if (!localStorage.getItem('hasLaunched')) localStorage.setItem('hasLaunched', 'true')

      if (startupScheduledRef.current) return
      startupScheduledRef.current = true
      startupTimerRef.current = setTimeout(() => {
        startupTimerRef.current = null
        // Keep the existing WfW cue untouched. Win95 no longer emits the
        // synthetic startup/menu/window tones that are absent from RTM defaults.
        if (useProgramStore.getState().settings.shell === 'win31') sounds.startupChime()
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
    // Both historical shells own fixed canonical palettes. Theme preferences
    // remain available to shell-neutral tools only.
    document.documentElement.classList.remove('theme-dark')
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

  if (isLauncherTools) return <LauncherTools />

  // Resolve active shell
  const shellDef = getShell(settings.shell ?? 'win31')
  const ShellComponent = shellDef?.component

  return (
    <div
      className={`app shell-${settings.shell ?? 'win31'} ${settings.shell === 'win31' && launchFeedbackStatus === 'launching' ? 'app-launching' : ''}`}
    >
      {ShellComponent && <ShellComponent platform={platform} />}
      {settings.shell === 'win31' && <LaunchFeedback />}
      {settings.shell === 'win31' && <DialogManager />}
      {settings.shell === 'win31' && quickSearchOpen && <QuickSearchOverlay />}
    </div>
  )
}

export default App
