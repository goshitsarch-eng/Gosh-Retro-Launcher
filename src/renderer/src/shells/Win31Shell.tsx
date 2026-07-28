import React, { useCallback, useEffect, useState } from 'react'
import { MenuBar } from '../components/Menu/MenuBar'
import { MenuItem } from '../components/Menu/MenuItem'
import { MenuSeparator } from '../components/Menu/MenuSeparator'
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
  const [isOuterMaximized, setIsOuterMaximized] = useState(false)

  const refreshMaximizedState = useCallback(async () => {
    setIsOuterMaximized(await window.electronAPI.window.isMaximized())
  }, [])

  useEffect(() => {
    void refreshMaximizedState()
  }, [refreshMaximizedState])

  // Group chrome scale CSS variables (Win31 MDI-specific)
  useEffect(() => {
    const scale = settings.groupChromeScale ?? 1
    const root = document.documentElement.style
    const titlebarHeight = Math.round(18 * scale)
    const controlButtonSize = Math.round(13 * scale)
    const titleFontSize = Math.round(12 * scale)
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

  useEffect(() => {
    if (activeMenu !== 'System') return
    const closeSystemMenu = (event: PointerEvent): void => {
      const target = event.target as HTMLElement
      if (target.closest('.win31-system-menu, .win31-outer-system-button')) return
      setActiveMenu(null)
    }
    document.addEventListener('pointerdown', closeSystemMenu)
    return () => document.removeEventListener('pointerdown', closeSystemMenu)
  }, [activeMenu, setActiveMenu])

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
    <div className="win31-program-manager-shell">
      <div
        className="win31-program-manager-caption"
        onDoubleClick={(event) => {
          if ((event.target as HTMLElement).closest('button')) return
          void window.electronAPI.window.maximize().then(refreshMaximizedState)
        }}
      >
        <button
          type="button"
          className="win31-outer-system-button"
          title="Close Program Manager"
          aria-label="Program Manager control menu"
          aria-haspopup="menu"
          aria-expanded={activeMenu === 'System'}
          onClick={() => setActiveMenu(activeMenu === 'System' ? null : 'System')}
          onDoubleClick={(event) => {
            event.stopPropagation()
            void window.electronAPI.window.close()
          }}
        >
          <span />
        </button>
        <span className="win31-program-manager-title">Program Manager</span>
        <div className="win31-outer-caption-controls">
          <button
            type="button"
            className="win31-outer-control-button"
            title="Minimize"
            aria-label="Minimize"
            onClick={() => void window.electronAPI.window.minimize()}
          >
            <span className="win31-glyph-minimize" />
          </button>
          <button
            type="button"
            className="win31-outer-control-button"
            title={isOuterMaximized ? 'Restore' : 'Maximize'}
            aria-label={isOuterMaximized ? 'Restore' : 'Maximize'}
            onClick={() => void window.electronAPI.window.maximize().then(refreshMaximizedState)}
          >
            <span className={isOuterMaximized ? 'win31-glyph-restore' : 'win31-glyph-maximize'} />
          </button>
        </div>
      </div>
      {activeMenu === 'System' && (
        <div className="win31-system-menu" role="menu">
          <MenuItem
            label="Restore"
            hotkey="R"
            disabled={!isOuterMaximized}
            onClick={() => {
              setActiveMenu(null)
              void window.electronAPI.window.maximize().then(refreshMaximizedState)
            }}
          />
          <MenuItem label="Move" hotkey="M" disabled />
          <MenuItem label="Size" hotkey="S" disabled />
          <MenuItem
            label="Minimize"
            hotkey="n"
            onClick={() => {
              setActiveMenu(null)
              void window.electronAPI.window.minimize()
            }}
          />
          <MenuItem
            label="Maximize"
            hotkey="x"
            disabled={isOuterMaximized}
            onClick={() => {
              setActiveMenu(null)
              void window.electronAPI.window.maximize().then(refreshMaximizedState)
            }}
          />
          <MenuSeparator />
          <MenuItem
            label="Close"
            hotkey="C"
            shortcut={platform === 'darwin' ? 'Cmd+F4' : 'Alt+F4'}
            onClick={() => {
              setActiveMenu(null)
              void window.electronAPI.window.close()
            }}
          />
        </div>
      )}
      <MenuBar platform={platform} />
      <MDIContainer />
      {!shortcutHintDismissed && (
        <div className="shortcut-hint">
          Press {modKey}+Shift+Space for Quick Search
        </div>
      )}
    </div>
  )
}
