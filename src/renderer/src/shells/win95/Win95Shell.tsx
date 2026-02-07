import React, { useEffect, useState } from 'react'
import { Win95Desktop } from './Win95Desktop'
import { Win95Taskbar } from './Win95Taskbar'
import { Win95StartMenu } from './Win95StartMenu'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import type { ShellProps } from '../types'

export const Win95Shell: React.FC<ShellProps> = ({ platform }) => {
  const settings = useProgramStore((state) => state.settings)
  const activeDialog = useUIStore((state) => state.activeDialog)
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const [startMenuOpen, setStartMenuOpen] = useState(false)

  const [shortcutHintDismissed, setShortcutHintDismissed] = useState(
    () => localStorage.getItem('quickSearchHintDismissed') === 'true'
  )

  // Group chrome scale CSS variables
  useEffect(() => {
    const scale = settings.groupChromeScale ?? 1
    const root = document.documentElement.style
    const titlebarHeight = Math.round(22 * scale)
    const controlButtonSize = Math.round(16 * scale)
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

  // Win95 keyboard shortcuts
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if (activeDialog !== null) return
      if (quickSearchOpen) return

      // Escape closes Start Menu
      if (event.key === 'Escape' && startMenuOpen) {
        event.preventDefault()
        setStartMenuOpen(false)
        return
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [activeDialog, quickSearchOpen, startMenuOpen])

  const handleStartClick = (): void => {
    setStartMenuOpen((prev) => !prev)
  }

  const handleStartMenuClose = (): void => {
    setStartMenuOpen(false)
  }

  const modKey = platform === 'darwin' ? 'Cmd' : 'Ctrl'

  return (
    <div className="win95-shell">
      <Win95Desktop />
      <Win95StartMenu isOpen={startMenuOpen} onClose={handleStartMenuClose} />
      <Win95Taskbar onStartClick={handleStartClick} startMenuOpen={startMenuOpen} />
      {!shortcutHintDismissed && (
        <div className="shortcut-hint">
          Press {modKey}+Shift+Space for Quick Search
        </div>
      )}
    </div>
  )
}
