import React, { useEffect } from 'react'
import { MenuBar } from './components/Menu/MenuBar'
import { MDIContainer } from './components/MDI/MDIContainer'
import { DialogManager } from './components/Dialogs/DialogManager'
import { QuickSearchOverlay } from './components/QuickSearch/QuickSearchOverlay'
import { useProgramStore } from './store/programStore'
import { useUIStore } from './store/uiStore'

const App: React.FC = () => {
  const loadData = useProgramStore((state) => state.loadData)
  const settings = useProgramStore((state) => state.settings)
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const toggleQuickSearch = useUIStore((state) => state.toggleQuickSearch)

  // Load data on mount
  useEffect(() => {
    loadData()
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
    }

    window.electronAPI.on('quick-search:toggle', handleToggle)

    return () => {
      window.electronAPI.off('quick-search:toggle', handleToggle)
    }
  }, [toggleQuickSearch])

  return (
    <div className="app">
      <MenuBar />
      <MDIContainer />
      <DialogManager />
      {quickSearchOpen && <QuickSearchOverlay />}
    </div>
  )
}

export default App
