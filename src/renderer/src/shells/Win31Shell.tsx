import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type CSSProperties,
  type JSX,
  type PointerEvent as ReactPointerEvent
} from 'react'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import {
  getGroupWindowState,
  type HostWindowBounds,
  type HostWindowState,
  type ProgramGroup,
  type ProgramItem
} from '@shared/types'
import { useProgramStore } from '../store/programStore'
import { useUIStore } from '../store/uiStore'
import { useMDIStore } from '../store/mdiStore'
import type { ShellProps } from './types'
import { Win31MenuBar, Win31PopupMenu, type Win31MenuItemModel } from './win31/Win31MenuBar'
import { Win31MDIContainer } from './win31/Win31MDIContainer'
import { Win31ScaleProvider, useWin31Scale } from './win31/Win31ScaleContext'
import type { Win31Command, Win31CommandState } from './win31/commands'
import { getWfwIconSrc } from './win31/iconCatalog'

const DEFAULT_HOST_STATE: HostWindowState = {
  focused: true,
  maximized: false,
  minimized: false,
  bounds: { x: 0, y: 0, width: 800, height: 600 }
}

function selectedObjects(
  groups: ProgramGroup[],
  selection: ReturnType<typeof useUIStore.getState>['win31Selection'],
  activeGroupId: string | null
): { group: ProgramGroup | null; item: ProgramItem | null } {
  if (selection?.kind === 'item') {
    const group = groups.find((entry) => entry.id === selection.groupId) ?? null
    return { group, item: group?.items.find((entry) => entry.id === selection.itemId) ?? null }
  }
  if (selection?.kind === 'groupIcon') {
    return { group: groups.find((entry) => entry.id === selection.groupId) ?? null, item: null }
  }
  return { group: groups.find((entry) => entry.id === activeGroupId) ?? null, item: null }
}

export const Win31Shell = ({ platform }: ShellProps): JSX.Element => (
  <Win31ScaleProvider>
    <Win31ProgramManager platform={platform} />
  </Win31ScaleProvider>
)

function Win31ProgramManager({ platform }: ShellProps): JSX.Element {
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const updateSettings = useProgramStore((state) => state.updateSettings)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const deleteGroup = useProgramStore((state) => state.deleteGroup)
  const deleteItem = useProgramStore((state) => state.deleteItem)
  const selection = useUIStore((state) => state.win31Selection)
  const setSelection = useUIStore((state) => state.setWin31Selection)
  const openDialog = useUIStore((state) => state.openDialog)
  const activeDialog = useUIStore((state) => state.activeDialog)
  const activeGroupId = useMDIStore((state) => state.activeWindowId)
  const focusWindow = useMDIStore((state) => state.focusWindow)
  const cascadeWindows = useMDIStore((state) => state.cascadeWindows)
  const tileWindows = useMDIStore((state) => state.tileWindows)
  const arrangeIcons = useMDIStore((state) => state.arrangeIcons)
  const { scale } = useWin31Scale()
  const [hostState, setHostState] = useState(DEFAULT_HOST_STATE)
  const [systemMenuOpen, setSystemMenuOpen] = useState(false)
  const [desktopBounds, setDesktopBounds] = useState(settings.win31ProgramManagerBounds)
  const [desktopMaximized, setDesktopMaximized] = useState(false)

  useEffect(() => setDesktopBounds(settings.win31ProgramManagerBounds), [settings.win31ProgramManagerBounds])

  const selected = useMemo(
    () => selectedObjects(groups, selection, activeGroupId),
    [activeGroupId, groups, selection]
  )

  useEffect(() => {
    let active = true
    void Promise.all([
      window.electronAPI.window.isMaximized(),
      window.electronAPI.window.getBounds()
    ]).then(([maximized, bounds]) => {
      if (active) setHostState((current) => ({ ...current, maximized, bounds }))
    })
    const handleState = (...args: unknown[]): void => {
      const next = args[0] as HostWindowState
      if (next?.bounds && typeof next.focused === 'boolean') setHostState(next)
    }
    window.electronAPI.on(IPC_CHANNELS.WINDOW_STATE_CHANGED, handleState)
    return () => {
      active = false
      window.electronAPI.off(IPC_CHANNELS.WINDOW_STATE_CHANGED, handleState)
    }
  }, [])

  useEffect(() => {
    if (!systemMenuOpen) return
    const dismiss = (event: PointerEvent): void => {
      const target = event.target as HTMLElement
      if (target.closest('.wfw-system-popup.outer, .wfw-system-button')) return
      setSystemMenuOpen(false)
    }
    document.addEventListener('pointerdown', dismiss)
    return () => document.removeEventListener('pointerdown', dismiss)
  }, [systemMenuOpen])

  useEffect(() => {
    const handleKeys = (event: KeyboardEvent): void => {
      if (activeDialog) return
      if (event.altKey && event.key === ' ') {
        event.preventDefault()
        setSystemMenuOpen((open) => !open)
      } else if (event.altKey && event.key === '-') {
        event.preventDefault()
        window.dispatchEvent(new CustomEvent('wfw-child-system-menu'))
      }
    }
    window.addEventListener('keydown', handleKeys)
    return () => window.removeEventListener('keydown', handleKeys)
  }, [activeDialog])

  const persistDesktopBounds = useCallback((bounds: typeof desktopBounds): void => {
    setDesktopBounds(bounds)
    updateSettings({ win31ProgramManagerBounds: bounds })
  }, [updateSettings])

  const toggleProgramManagerMaximize = useCallback((): void => {
    if (settings.win31DesktopMode) setDesktopMaximized((maximized) => !maximized)
    else void window.electronAPI.window.maximize()
  }, [settings.win31DesktopMode])

  const minimizeProgramManager = useCallback((): void => {
    if (settings.win31DesktopMode) updateSettings({ win31ProgramManagerMinimized: true })
    else void window.electronAPI.window.minimize()
  }, [settings.win31DesktopMode, updateSettings])

  const restoreGroup = useCallback((group: ProgramGroup): void => {
    updateGroupWindowState(group.id, { minimized: false }, 'win31')
    focusWindow(group.id)
    setSelection(null)
  }, [focusWindow, setSelection, updateGroupWindowState])

  const launchItem = useCallback(async (item: ProgramItem): Promise<void> => {
    const result = await window.electronAPI.program.launch(item)
    if (!result.success) {
      openDialog('confirm', {
        confirmOptions: {
          title: 'Program Manager',
          message: result.error ?? `Cannot run ${item.name}.`,
          onConfirm: () => undefined
        }
      })
      return
    }
    if (settings.minimizeOnUse && selected.group) {
      updateGroupWindowState(selected.group.id, { minimized: true }, 'win31')
    }
  }, [openDialog, selected.group, settings.minimizeOnUse, updateGroupWindowState])

  useEffect(() => {
    const keyboard = (event: KeyboardEvent): void => {
      if (activeDialog) return
      const target = event.target as HTMLElement | null
      const editing = target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement || target instanceof HTMLSelectElement
      if (editing) return

      if (event.key === 'F1' && !event.ctrlKey && !event.altKey) {
        event.preventDefault(); openDialog('help', { helpTopic: 'contents' }); return
      }
      if (event.altKey && event.key === 'F4') {
        event.preventDefault()
        if (settings.win31DesktopMode) openDialog('exitWindows')
        else void window.electronAPI.window.close()
        return
      }
      if (event.shiftKey && !event.ctrlKey && !event.altKey && event.key === 'F4') {
        event.preventDefault(); tileWindows(); return
      }
      if (event.shiftKey && !event.ctrlKey && !event.altKey && event.key === 'F5') {
        event.preventDefault(); cascadeWindows(); return
      }
      if (event.ctrlKey && !event.altKey && event.key === 'F6') {
        const visible = groups.filter((group) => !getGroupWindowState(group, 'win31').minimized)
        if (visible.length) {
          event.preventDefault()
          const current = visible.findIndex((group) => group.id === activeGroupId)
          focusWindow(visible[(current + 1 + visible.length) % visible.length].id)
        }
        return
      }
      if (event.ctrlKey && !event.altKey && event.key === 'F4' && selected.group) {
        event.preventDefault()
        updateGroupWindowState(selected.group.id, { minimized: true }, 'win31')
        return
      }
      if (event.altKey && event.key === 'Enter' && selected.group) {
        event.preventDefault()
        if (selected.item) openDialog('itemProperties', { groupId: selected.group.id, item: selected.item })
        else openDialog('groupProperties', { group: selected.group })
        return
      }
      if (event.key === 'Delete' && selected.group) {
        event.preventDefault()
        if (selected.item) {
          openDialog('confirm', { confirmOptions: {
            title: 'Delete Program Item', message: `Delete the program item “${selected.item.name}”?`,
            onConfirm: () => deleteItem(selected.group!.id, selected.item!.id)
          } })
        } else {
          openDialog('confirm', { confirmOptions: {
            title: 'Delete Program Group', message: `Delete the program group “${selected.group.name}”?`,
            onConfirm: () => deleteGroup(selected.group!.id)
          } })
        }
        return
      }

      if (event.altKey && !event.ctrlKey && !event.shiftKey && !event.metaKey &&
        ['f', 'o', 'w', 'h', ' ', '-', 'enter'].includes(event.key.toLowerCase())) return

      const shortcut = groups.flatMap((group) => group.items.map((item) => ({ group, item })))
        .find(({ item }) => shortcutMatches(item.shortcutKey, event))
      if (shortcut) {
        event.preventDefault()
        void launchItem(shortcut.item)
      }
    }
    window.addEventListener('keydown', keyboard)
    return () => window.removeEventListener('keydown', keyboard)
  }, [activeDialog, activeGroupId, cascadeWindows, deleteGroup, deleteItem, focusWindow, groups, launchItem,
    openDialog, selected.group, selected.item, settings.win31DesktopMode, tileWindows, updateGroupWindowState])

  const commandState = useCallback((command: Win31Command): Win31CommandState => {
    const visibleGroups = groups.filter((group) => !getGroupWindowState(group, 'win31').minimized)
    const minimizedGroups = groups.filter((group) => getGroupWindowState(group, 'win31').minimized)
    switch (command) {
      case 'open':
        return { disabled: !selected.item && selection?.kind !== 'groupIcon' }
      case 'move':
      case 'copy':
        return { disabled: !selected.item || groups.length < 1 }
      case 'delete':
      case 'properties':
        return { disabled: !selected.group }
      case 'cascade':
      case 'tile':
        return { disabled: visibleGroups.length === 0 }
      case 'arrange-icons':
        return { disabled: minimizedGroups.length === 0 }
      case 'auto-arrange':
        return { checked: settings.autoArrange }
      case 'minimize-on-use':
        return { checked: settings.minimizeOnUse }
      case 'save-settings':
        return { checked: settings.saveSettingsOnExit }
      default:
        return {}
    }
  }, [groups, selected.group, selected.item, selection?.kind, settings.autoArrange, settings.minimizeOnUse, settings.saveSettingsOnExit])

  const runCommand = useCallback((command: Win31Command): void => {
    setSystemMenuOpen(false)
    if (command.startsWith('group:')) {
      const group = groups.find((entry) => entry.id === command.slice(6))
      if (group) restoreGroup(group)
      return
    }
    switch (command) {
      case 'new':
        openDialog('newObject', { groupId: selected.group?.id })
        break
      case 'open':
        if (selected.item) void launchItem(selected.item)
        else if (selected.group) restoreGroup(selected.group)
        break
      case 'move':
      case 'copy':
        if (selected.item && selected.group) {
          openDialog(command === 'move' ? 'moveItem' : 'copyItem', {
            groupId: selected.group.id,
            item: selected.item,
            copyMode: command === 'copy'
          })
        }
        break
      case 'delete':
        if (selected.item && selected.group) {
          openDialog('confirm', {
            confirmOptions: {
              title: 'Delete Program Item',
              message: `Delete the program item “${selected.item.name}”?`,
              onConfirm: () => deleteItem(selected.group!.id, selected.item!.id)
            }
          })
        } else if (selected.group) {
          openDialog('confirm', {
            confirmOptions: {
              title: 'Delete Program Group',
              message: `Delete the program group “${selected.group.name}” and all its items?`,
              onConfirm: () => deleteGroup(selected.group!.id)
            }
          })
        }
        break
      case 'properties':
        if (selected.item && selected.group) {
          openDialog('itemProperties', { groupId: selected.group.id, item: selected.item })
        } else if (selected.group) {
          openDialog('groupProperties', { group: selected.group })
        }
        break
      case 'run':
        openDialog('run')
        break
      case 'exit':
        openDialog('exitWindows')
        break
      case 'auto-arrange':
        updateSettings({ autoArrange: !settings.autoArrange })
        break
      case 'minimize-on-use':
        updateSettings({ minimizeOnUse: !settings.minimizeOnUse })
        break
      case 'save-settings':
        updateSettings({ saveSettingsOnExit: !settings.saveSettingsOnExit })
        break
      case 'cascade':
        cascadeWindows()
        break
      case 'tile':
        tileWindows()
        break
      case 'arrange-icons':
        arrangeIcons()
        break
      case 'help-contents':
      case 'help-search':
      case 'help-using':
        openDialog('help', {
          helpTopic: command === 'help-search' ? 'search' : command === 'help-using' ? 'using' : 'contents'
        })
        break
      case 'about':
        openDialog('about')
        break
      case 'outer-restore':
      case 'outer-maximize':
        toggleProgramManagerMaximize()
        break
      case 'outer-move':
      case 'outer-size':
        if (settings.win31DesktopMode) {
          beginDesktopKeyboardOperation(command === 'outer-move' ? 'move' : 'size', desktopBounds, persistDesktopBounds)
        } else {
          void beginHostKeyboardOperation(command === 'outer-move' ? 'move' : 'size', hostState.bounds)
        }
        break
      case 'outer-minimize':
        minimizeProgramManager()
        break
      case 'outer-close':
        if (settings.win31DesktopMode) openDialog('exitWindows')
        else void window.electronAPI.window.close()
        break
    }
  }, [arrangeIcons, cascadeWindows, deleteGroup, deleteItem, groups, hostState.bounds, launchItem, openDialog,
    desktopBounds, minimizeProgramManager, persistDesktopBounds, restoreGroup, selected.group,
    selected.item, settings.autoArrange, settings.minimizeOnUse, settings.saveSettingsOnExit,
    settings.win31DesktopMode, tileWindows, toggleProgramManagerMaximize, updateSettings])

  const effectiveMaximized = settings.win31DesktopMode ? desktopMaximized : hostState.maximized
  const systemItems = useMemo<Win31MenuItemModel[]>(() => [
    { command: 'outer-restore', label: '&Restore', disabled: !effectiveMaximized },
    { command: 'outer-move', label: '&Move', disabled: effectiveMaximized },
    { command: 'outer-size', label: '&Size', disabled: effectiveMaximized },
    { command: 'outer-minimize', label: 'Mi&nimize' },
    { command: 'outer-maximize', label: 'Ma&ximize', disabled: effectiveMaximized },
    { separator: true },
    { command: 'outer-close', label: '&Close' }
  ], [effectiveMaximized])

  const rootStyle = { '--wfw-scale': scale } as CSSProperties
  const logicalWidth = hostState.bounds.width / scale
  const logicalHeight = hostState.bounds.height / scale
  const managerBounds = desktopMaximized
    ? { x: 0, y: 0, width: logicalWidth, height: logicalHeight }
    : desktopBounds
  const managerStyle = settings.win31DesktopMode ? {
    left: managerBounds.x * scale,
    top: managerBounds.y * scale,
    width: managerBounds.width,
    height: managerBounds.height
  } : undefined

  const beginDesktopDrag = (event: ReactPointerEvent<HTMLDivElement>): void => {
    if (!settings.win31DesktopMode || desktopMaximized || (event.target as HTMLElement).closest('button')) return
    const start = { x: event.clientX, y: event.clientY, bounds: desktopBounds }
    const element = event.currentTarget
    element.setPointerCapture(event.pointerId)
    const calculate = (pointer: PointerEvent) => ({
      ...start.bounds,
      x: Math.round(Math.max(0, Math.min(logicalWidth - 80, start.bounds.x + (pointer.clientX - start.x) / scale))),
      y: Math.round(Math.max(0, Math.min(logicalHeight - 24, start.bounds.y + (pointer.clientY - start.y) / scale)))
    })
    const move = (pointer: PointerEvent): void => setDesktopBounds(calculate(pointer))
    const end = (pointer: PointerEvent): void => {
      element.removeEventListener('pointermove', move)
      element.removeEventListener('pointerup', end)
      element.removeEventListener('pointercancel', end)
      persistDesktopBounds(calculate(pointer))
    }
    element.addEventListener('pointermove', move)
    element.addEventListener('pointerup', end)
    element.addEventListener('pointercancel', end)
  }

  const desktopMinimized = settings.win31DesktopMode && settings.win31ProgramManagerMinimized
  return (
    <div className={`wfw-scale-viewport ${settings.win31DesktopMode ? 'desktop-mode' : ''}`} style={rootStyle}>
      {desktopMinimized && (
        <button
          className="wfw-desktop-program-manager-icon"
          style={{ left: scale, top: Math.max(8, hostState.bounds.height - 70 * scale) }}
          onDoubleClick={() => updateSettings({ win31ProgramManagerMinimized: false })}
          onKeyDown={(event) => {
            if (event.key === 'Enter') updateSettings({ win31ProgramManagerMinimized: false })
          }}
        >
          <img src={getWfwIconSrc('program-manager', scale)} alt="" />
          <span>Program<br />Manager</span>
        </button>
      )}
      {!desktopMinimized && (
      <div
        className={`wfw-program-manager ${settings.win31DesktopMode ? 'desktop-window' : ''} ${hostState.focused ? 'active' : 'inactive'} ${effectiveMaximized ? 'host-maximized' : ''}`}
        style={managerStyle}
      >
        <div
          className="wfw-outer-caption"
          onPointerDown={beginDesktopDrag}
          onDoubleClick={(event) => {
            if (!(event.target as HTMLElement).closest('button')) toggleProgramManagerMaximize()
          }}
        >
          <button
            type="button"
            className="wfw-system-button"
            aria-label="Program Manager control menu"
            aria-haspopup="menu"
            aria-expanded={systemMenuOpen}
            onPointerDown={(event) => event.stopPropagation()}
            onClick={() => setSystemMenuOpen((open) => !open)}
            onDoubleClick={(event) => {
              event.stopPropagation()
              runCommand('outer-close')
            }}
          ><span /></button>
          <strong>Program Manager</strong>
          <div className="wfw-outer-caption-controls">
            <button type="button" aria-label="Minimize" onClick={minimizeProgramManager}>
              <span className="wfw-glyph-down" />
            </button>
            <button type="button" aria-label={effectiveMaximized ? 'Restore' : 'Maximize'} onClick={toggleProgramManagerMaximize}>
              <span className={effectiveMaximized ? 'wfw-glyph-restore' : 'wfw-glyph-up'} />
            </button>
          </div>
          {systemMenuOpen && (
            <Win31PopupMenu
              className="wfw-system-popup outer"
              items={systemItems}
              onCommand={runCommand}
              onDismiss={() => setSystemMenuOpen(false)}
            />
          )}
        </div>
        <Win31MenuBar
          groups={groups}
          activeGroupId={activeGroupId}
          commandState={commandState}
          onCommand={runCommand}
          disabled={activeDialog !== null}
        />
        <Win31MDIContainer />
        <span className="wfw-platform-sr-only">{platform}</span>
      </div>
      )}
    </div>
  )
}

function shortcutMatches(shortcut: string | undefined, event: KeyboardEvent): boolean {
  if (!shortcut?.trim()) return false
  const parts = shortcut.toLowerCase().split('+').map((part) => part.trim()).filter(Boolean)
  const key = parts.at(-1)
  if (!key || event.key.toLowerCase() !== key) return false
  return event.ctrlKey === parts.includes('ctrl') &&
    event.altKey === parts.includes('alt') &&
    event.shiftKey === parts.includes('shift') &&
    event.metaKey === (parts.includes('meta') || parts.includes('win'))
}

function beginDesktopKeyboardOperation(
  mode: 'move' | 'size',
  initialBounds: { x: number; y: number; width: number; height: number },
  commit: (bounds: { x: number; y: number; width: number; height: number }) => void
): void {
  let bounds = { ...initialBounds }
  const handleKey = (event: KeyboardEvent): void => {
    if (event.key === 'Escape' || event.key === 'Enter') {
      event.preventDefault()
      window.removeEventListener('keydown', handleKey)
      commit(event.key === 'Escape' ? initialBounds : bounds)
      return
    }
    const step = event.shiftKey ? 8 : 1
    if (event.key === 'ArrowLeft') {
      if (mode === 'move') bounds.x = Math.max(0, bounds.x - step)
      else bounds.width = Math.max(320, bounds.width - step)
    } else if (event.key === 'ArrowRight') {
      if (mode === 'move') bounds.x += step
      else bounds.width += step
    } else if (event.key === 'ArrowUp') {
      if (mode === 'move') bounds.y = Math.max(0, bounds.y - step)
      else bounds.height = Math.max(240, bounds.height - step)
    } else if (event.key === 'ArrowDown') {
      if (mode === 'move') bounds.y += step
      else bounds.height += step
    } else return
    event.preventDefault()
    // Commit each key so keyboard movement paints immediately and is persisted.
    commit({ ...bounds })
  }
  window.addEventListener('keydown', handleKey)
}

async function beginHostKeyboardOperation(
  mode: 'move' | 'size',
  initialBounds: HostWindowBounds
): Promise<void> {
  let bounds = { ...initialBounds }
  const handleKey = (event: KeyboardEvent): void => {
    if (event.key === 'Escape' || event.key === 'Enter') {
      event.preventDefault()
      window.removeEventListener('keydown', handleKey)
      if (event.key === 'Escape') void window.electronAPI.window.setBounds(initialBounds)
      return
    }
    const step = event.shiftKey ? 10 : 1
    if (event.key === 'ArrowLeft') {
      if (mode === 'move') bounds.x -= step
      else bounds.width = Math.max(400, bounds.width - step)
    } else if (event.key === 'ArrowRight') {
      if (mode === 'move') bounds.x += step
      else bounds.width += step
    } else if (event.key === 'ArrowUp') {
      if (mode === 'move') bounds.y -= step
      else bounds.height = Math.max(300, bounds.height - step)
    } else if (event.key === 'ArrowDown') {
      if (mode === 'move') bounds.y += step
      else bounds.height += step
    } else return
    event.preventDefault()
    void window.electronAPI.window.setBounds(bounds)
  }
  window.addEventListener('keydown', handleKey)
}
