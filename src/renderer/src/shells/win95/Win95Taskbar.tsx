import { useEffect, useMemo, useRef, useState, type JSX } from 'react'
import { getGroupWindowState, type LogicalRect } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { getWin95IconSrc } from './iconCatalog'
import { useWin95Scale } from './Win95ScaleContext'
import { useWin95WindowStore } from './windowStore'
import { useWin95PointerHandler } from './Win95InputController'
import { Win95PopupMenu, type Win95MenuItemModel } from './Win95Menu'
import { Win95BitmapText } from './bitmapText'
import { getTaskbarButtonState, getTaskbarClickAction } from './taskbarState'
import { WIN95_METRICS } from './tokens'

interface Win95TaskbarProps {
  onStartClick: () => void
  startMenuOpen: boolean
}

function formatClock(date = new Date()): string {
  return new Intl.DateTimeFormat('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  }).format(date)
}

export function Win95Taskbar({ onStartClick, startMenuOpen }: Win95TaskbarProps): JSX.Element {
  const groups = useProgramStore((state) => state.groups)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const windows = useWin95WindowStore((state) => state.windows)
  const activeWindowId = useWin95WindowStore((state) => state.activeWindowId)
  const focusWindow = useWin95WindowStore((state) => state.focusWindow)
  const closeWindow = useWin95WindowStore((state) => state.closeWindow)
  const deactivateWindow = useWin95WindowStore((state) => state.deactivateWindow)
  const updateSystemWindow = useWin95WindowStore((state) => state.updateSystemWindow)
  const requestWindowCommand = useWin95WindowStore((state) => state.requestWindowCommand)
  const { scale, logicalViewport, toLogicalPoint } = useWin95Scale()
  const [clock, setClock] = useState(() => formatClock())
  const [context, setContext] = useState<{ x: number; y: number; windowId?: string } | null>(null)
  const startTracking = useRef(false)
  const dragHover = useRef<{ id: string; timer: number } | null>(null)

  useWin95PointerHandler('pointerup', 'start-button-tracking', () => {
    if (!startTracking.current) return false
    window.setTimeout(() => {
      startTracking.current = false
      delete document.documentElement.dataset.win95StartTracking
    }, 0)
    return false
  }, startTracking.current || startMenuOpen)

  const activateWindow = (id: string): void => {
    const entry = windows.find((candidate) => candidate.id === id)
    if (!entry) return
    const group = entry.groupId ? groups.find((candidate) => candidate.id === entry.groupId) : undefined
    if (group) updateGroupWindowState(group.id, { minimized: false }, 'win95')
    else updateSystemWindow(id, { systemMinimized: false })
    focusWindow(id)
  }
  const scheduleDragHover = (id: string | null): void => {
    if (dragHover.current?.id === id) return
    if (dragHover.current) window.clearTimeout(dragHover.current.timer)
    dragHover.current = null
    if (!id) return
    const timer = window.setTimeout(() => { activateWindow(id); dragHover.current = null }, 500)
    dragHover.current = { id, timer }
  }
  useWin95PointerHandler('pointermove', 'taskbar-drag-hover', (event) => {
    if (!document.documentElement.dataset.win95Dragging) { scheduleDragHover(null); return false }
    const id = document.elementFromPoint(event.clientX, event.clientY)?.closest<HTMLElement>('[data-task-window]')?.dataset.taskWindow ?? null
    scheduleDragHover(id)
    return !!id
  })

  useEffect(() => {
    const captureClock = (event: Event): void => {
      const value = (event as CustomEvent<string>).detail
      if (value) setClock(value)
    }
    window.addEventListener('win95-capture-clock', captureClock)
    const tick = (): void => setClock(formatClock())
    const delay = 60000 - (Date.now() % 60000)
    let interval: ReturnType<typeof setInterval> | undefined
    const timer = setTimeout(() => { tick(); interval = setInterval(tick, 60000) }, delay)
    return () => {
      clearTimeout(timer)
      if (interval) clearInterval(interval)
      if (dragHover.current) window.clearTimeout(dragHover.current.timer)
      window.removeEventListener('win95-capture-clock', captureClock)
    }
  }, [])

  const clickWindow = (id: string): void => {
    const entry = windows.find((candidate) => candidate.id === id)
    if (!entry) return
    const group = entry.groupId ? groups.find((candidate) => candidate.id === entry.groupId) : undefined
    const minimized = group ? getGroupWindowState(group, 'win95').minimized : !!entry.systemMinimized
    const action = getTaskbarClickAction(id, activeWindowId, minimized)
    if (action === 'minimize') {
      if (group) updateGroupWindowState(group.id, { minimized: true }, 'win95')
      else updateSystemWindow(id, { systemMinimized: true })
      deactivateWindow(id)
      return
    }
    if (action === 'restore-focus') activateWindow(id)
    else focusWindow(id)
  }

  const target = context?.windowId ? windows.find((entry) => entry.id === context.windowId) : undefined
  const targetGroup = target?.groupId ? groups.find((group) => group.id === target.groupId) : undefined
  const targetState = targetGroup ? getGroupWindowState(targetGroup, 'win95') : target
    ? {
      minimized: !!target.systemMinimized,
      maximized: !!target.systemMaximized,
      ...(target.systemBounds ?? { x: 0, y: 0, width: 430, height: 300 }),
      restoreX: target.systemRestoreBounds?.x,
      restoreY: target.systemRestoreBounds?.y,
      restoreWidth: target.systemRestoreBounds?.width,
      restoreHeight: target.systemRestoreBounds?.height
    }
    : null

  const restoreTarget = (): void => {
    if (!target || !targetState) return
    if (targetGroup) {
      const updates = targetState.maximized ? {
        x: targetState.restoreX ?? targetState.x,
        y: targetState.restoreY ?? targetState.y,
        width: targetState.restoreWidth ?? targetState.width,
        height: targetState.restoreHeight ?? targetState.height,
        maximized: false,
        minimized: false
      } : { minimized: false }
      updateGroupWindowState(targetGroup.id, updates, 'win95')
    } else updateSystemWindow(target.id, {
      systemMinimized: false,
      systemMaximized: false,
      ...(target.systemRestoreBounds ? { systemBounds: target.systemRestoreBounds } : {})
    })
    focusWindow(target.id)
  }
  const minimizeTarget = (): void => {
    if (!target) return
    if (targetGroup) updateGroupWindowState(targetGroup.id, { minimized: true }, 'win95')
    else updateSystemWindow(target.id, { systemMinimized: true })
    deactivateWindow(target.id)
  }
  const maximizeTarget = (): void => {
    if (!target || !targetState) return
    if (targetGroup) updateGroupWindowState(targetGroup.id, {
      restoreX: targetState.maximized ? targetState.restoreX : targetState.x,
      restoreY: targetState.maximized ? targetState.restoreY : targetState.y,
      restoreWidth: targetState.maximized ? targetState.restoreWidth : targetState.width,
      restoreHeight: targetState.maximized ? targetState.restoreHeight : targetState.height,
      minimized: false,
      maximized: true
    }, 'win95')
    else updateSystemWindow(target.id, {
      systemRestoreBounds: target.systemMaximized ? target.systemRestoreBounds : target.systemBounds,
      systemMinimized: false,
      systemMaximized: true
    })
    focusWindow(target.id)
  }
  const closeTarget = (): void => {
    if (!target) return
    if (targetGroup) updateGroupWindowState(targetGroup.id, { minimized: false }, 'win95')
    closeWindow(target.id)
  }

  const visible = windows.filter((entry) => {
    const group = entry.groupId ? groups.find((candidate) => candidate.id === entry.groupId) : undefined
    return group ? !getGroupWindowState(group, 'win95').minimized : !entry.systemMinimized
  })
  const applyRect = (entryId: string, rect: LogicalRect): void => {
    const entry = windows.find((candidate) => candidate.id === entryId)
    const group = entry?.groupId ? groups.find((candidate) => candidate.id === entry.groupId) : undefined
    if (group) updateGroupWindowState(group.id, { ...rect, minimized: false, maximized: false }, 'win95')
    else if (entry) updateSystemWindow(entry.id, { systemBounds: rect, systemMinimized: false, systemMaximized: false })
  }
  const arrangeWindows = (mode: 'cascade' | 'horizontal' | 'vertical'): void => {
    if (!visible.length) return
    const work = { width: logicalViewport.width, height: logicalViewport.height - WIN95_METRICS.taskbarHeight }
    visible.forEach((entry, index) => {
      let rect: LogicalRect
      if (mode === 'cascade') rect = { x: 18 + index * 24, y: 18 + index * 24, width: Math.max(250, work.width - 180), height: Math.max(150, work.height - 140) }
      else if (mode === 'horizontal') rect = { x: 0, y: Math.floor(index * work.height / visible.length), width: work.width, height: Math.ceil(work.height / visible.length) }
      else rect = { x: Math.floor(index * work.width / visible.length), y: 0, width: Math.ceil(work.width / visible.length), height: work.height }
      applyRect(entry.id, rect)
    })
  }
  const minimizeAll = (): void => visible.forEach((entry) => {
    const group = entry.groupId ? groups.find((candidate) => candidate.id === entry.groupId) : undefined
    if (group) updateGroupWindowState(group.id, { minimized: true }, 'win95')
    else updateSystemWindow(entry.id, { systemMinimized: true })
    deactivateWindow(entry.id)
  })

  const windowMenu = useMemo<Win95MenuItemModel[]>(() => [
    { id: 'restore', label: '&Restore', disabled: !targetState?.minimized && !targetState?.maximized, onSelect: restoreTarget },
    { id: 'move', label: '&Move', disabled: !!targetState?.minimized, onSelect: () => target && requestWindowCommand(target.id, 'move') },
    { id: 'size', label: '&Size', disabled: !!targetState?.minimized || !!targetState?.maximized, onSelect: () => target && requestWindowCommand(target.id, 'size') },
    { id: 'minimize', label: 'Mi&nimize', disabled: !!targetState?.minimized, onSelect: minimizeTarget },
    { id: 'maximize', label: 'Ma&ximize', disabled: !!targetState?.maximized, onSelect: maximizeTarget },
    { id: 'sep', separator: true },
    { id: 'close', label: '&Close', defaultItem: true, onSelect: closeTarget }
  ], [target?.id, targetState?.maximized, targetState?.minimized])
  const backgroundMenu = useMemo<Win95MenuItemModel[]>(() => [
    { id: 'cascade', label: '&Cascade Windows', disabled: !visible.length, onSelect: () => arrangeWindows('cascade') },
    { id: 'tile-h', label: 'Tile Windows &Horizontally', disabled: !visible.length, onSelect: () => arrangeWindows('horizontal') },
    { id: 'tile-v', label: 'Tile Windows &Vertically', disabled: !visible.length, onSelect: () => arrangeWindows('vertical') },
    { id: 'minimize-all', label: '&Minimize All Windows', disabled: !visible.length, onSelect: minimizeAll },
    { id: 'sep', separator: true },
    { id: 'properties', label: '&Properties', icon: 'properties', onSelect: () => void window.electronAPI.app.openLauncherTools() }
  ], [visible.length, logicalViewport.height, logicalViewport.width])

  return (
    <div className="win95-taskbar" role="toolbar" aria-label="Taskbar"
      onContextMenu={(event) => {
        event.preventDefault()
        const root = event.currentTarget.closest('.win95-scale-root')?.getBoundingClientRect()
        const point = toLogicalPoint(event.clientX, event.clientY, root ?? undefined)
        setContext({ x: point.x, y: point.y })
      }}>
      <button type="button" className={`win95-start-button ${startMenuOpen ? 'pressed' : ''}`}
        aria-pressed={startMenuOpen}
        onPointerDown={(event) => {
          event.stopPropagation()
          if (event.button === 0 && !startMenuOpen) {
            startTracking.current = true
            document.documentElement.dataset.win95StartTracking = 'true'
            onStartClick()
          }
        }}
        onClick={() => { if (!startTracking.current) onStartClick() }}>
        <img src={getWin95IconSrc('windows-logo', 'small', scale)} alt="" />
        <Win95BitmapText text="Start" bold />
      </button>
      <div className="win95-task-buttons">
        {windows.map((entry) => {
          const group = entry.groupId ? groups.find((candidate) => candidate.id === entry.groupId) : undefined
          if (entry.kind === 'group' && !group) return null
          const minimized = group ? getGroupWindowState(group, 'win95').minimized : !!entry.systemMinimized
          const buttonState = getTaskbarButtonState(entry.id, activeWindowId, minimized)
          const active = buttonState === 'active'
          const title = group?.name ?? (entry.kind === 'my-computer' ? 'My Computer' : 'Find: Programs')
          return (
            <button type="button" key={entry.id} data-task-window={entry.id} className={`win95-task-button ${active ? 'pressed active' : ''}`}
              title={title} aria-pressed={active}
              onClick={() => clickWindow(entry.id)}
              onDragEnter={(event) => { event.preventDefault(); scheduleDragHover(entry.id) }}
              onDragOver={(event) => event.preventDefault()}
              onDragLeave={() => scheduleDragHover(null)}
              onContextMenu={(event) => {
                event.preventDefault(); event.stopPropagation()
                const root = event.currentTarget.closest('.win95-scale-root')?.getBoundingClientRect()
                const point = toLogicalPoint(event.clientX, event.clientY, root ?? undefined)
                setContext({ x: point.x, y: point.y, windowId: entry.id })
              }}>
              <img src={getWin95IconSrc(group?.icon ?? (entry.kind === 'my-computer' ? 'my-computer' : 'find'), 'small', scale)} alt="" />
              <Win95BitmapText text={title} bold={active} maxWidth={126} />
            </button>
          )
        })}
      </div>
      <div className="win95-tray" aria-label="Notification area"><Win95BitmapText className="win95-clock" text={clock} /></div>
      {context && <Win95PopupMenu items={context.windowId ? windowMenu : backgroundMenu} x={context.x} y={context.y}
        bottomInset={WIN95_METRICS.taskbarHeight} onClose={() => setContext(null)} roleLabel={context.windowId ? 'Task button menu' : 'Taskbar menu'} />}
    </div>
  )
}

export { formatClock }
