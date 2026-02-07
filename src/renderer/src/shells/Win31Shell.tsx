import React, { useEffect, useState } from 'react'
import { MenuBar } from '../components/Menu/MenuBar'
import { MDIContainer } from '../components/MDI/MDIContainer'
import { useProgramStore } from '../store/programStore'
import { useUIStore } from '../store/uiStore'
import { useMDIStore } from '../store/mdiStore'
import type { ShellProps } from './types'

export const Win31Shell: React.FC<ShellProps> = ({ platform }) => {
  const settings = useProgramStore((state) => state.settings)
  const activeMenu = useUIStore((state) => state.activeMenu)
  const setActiveMenu = useUIStore((state) => state.setActiveMenu)
  const activeDialog = useUIStore((state) => state.activeDialog)
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const cascadeWindows = useMDIStore((state) => state.cascadeWindows)
  const tileWindows = useMDIStore((state) => state.tileWindows)

  const [shortcutHintDismissed, setShortcutHintDismissed] = useState(
    () => localStorage.getItem('quickSearchHintDismissed') === 'true'
  )

  // Group chrome scale CSS variables (Win31 MDI-specific)
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

  // Dismiss shortcut hint when quick search is toggled via IPC
  useEffect(() => {
    const handleToggle = (): void => {
      if (!shortcutHintDismissed) {
        setShortcutHintDismissed(true)
        localStorage.setItem('quickSearchHintDismissed', 'true')
      }
    }
    window.electronAPI.on('quick-search:toggle', handleToggle)
    return () => {
      window.electronAPI.off('quick-search:toggle', handleToggle)
    }
  }, [shortcutHintDismissed])

  // Win31-specific keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if (activeDialog !== null) return
      if (quickSearchOpen) return

      const activeEl = document.activeElement
      const isInputFocused =
        activeEl instanceof HTMLInputElement ||
        activeEl instanceof HTMLTextAreaElement ||
        activeEl instanceof HTMLSelectElement

      // Alt+key menu shortcuts (Win31 menu bar navigation)
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

      // Shift+F4 -> tile windows (Win31 MDI)
      if (event.key === 'F4' && event.shiftKey && !event.ctrlKey && !event.altKey) {
        event.preventDefault()
        tileWindows()
        return
      }

      // Shift+F5 -> cascade windows (Win31 MDI)
      if (event.key === 'F5' && event.shiftKey && !event.ctrlKey && !event.altKey) {
        event.preventDefault()
        cascadeWindows()
        return
      }

      // Escape -> close menu (Win31 menu specific)
      if (event.key === 'Escape' && activeMenu !== null) {
        event.preventDefault()
        setActiveMenu(null)
        return
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [activeDialog, quickSearchOpen, activeMenu, setActiveMenu, tileWindows, cascadeWindows])

  const modKey = platform === 'darwin' ? 'Cmd' : 'Ctrl'

  return (
    <>
      <MenuBar platform={platform} />
      <MDIContainer />
      {!shortcutHintDismissed && (
        <div className="shortcut-hint">
          Press {modKey}+Shift+Space for Quick Search
        </div>
      )}
    </>
  )
}
