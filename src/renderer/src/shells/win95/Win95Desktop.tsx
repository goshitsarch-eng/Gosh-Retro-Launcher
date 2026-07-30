import { useEffect, useMemo, useRef, useState, type CSSProperties, type JSX, type PointerEvent as ReactPointerEvent } from 'react'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import type { HostWindowState } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { getWin95IconSrc } from './iconCatalog'
import { useWin95Scale } from './Win95ScaleContext'
import { Win95Window } from './Win95Window'
import { Win95PopupMenu, type Win95MenuItemModel } from './Win95Menu'
import { useWin95PointerHandler } from './Win95InputController'
import { useWin95WindowStore } from './windowStore'
import { Win95BitmapText } from './bitmapText'
import {
  findWin95DirectionalItem,
  findWin95TypeMatch,
  itemsInWin95Marquee,
  normalizeWin95Marquee,
  selectWin95All,
  selectWin95Item,
  snapWin95Position,
  type Win95MarqueeRect,
  type Win95SelectionState
} from './selectionState'
import { WIN95_METRICS } from './tokens'

type DesktopIconId = 'my-computer' | 'network-neighborhood' | 'recycle-empty'

const DESKTOP_ICONS: Array<{ id: DesktopIconId; label: string }> = [
  { id: 'my-computer', label: 'My Computer' },
  { id: 'network-neighborhood', label: 'Network Neighborhood' },
  { id: 'recycle-empty', label: 'Recycle Bin' }
]
const DEFAULT_POSITIONS: Record<DesktopIconId, { x: number; y: number }> = {
  'my-computer': { x: 4, y: 4 },
  'network-neighborhood': { x: 4, y: 78 },
  'recycle-empty': { x: 4, y: 152 }
}
const DESKTOP_IDS = DESKTOP_ICONS.map((icon) => icon.id)

interface IconDragState {
  ids: DesktopIconId[]
  startClient: { x: number; y: number }
  origins: Record<string, { x: number; y: number }>
  dx: number
  dy: number
  moved: boolean
}
interface MarqueeState {
  start: { x: number; y: number }
  rect: Win95MarqueeRect
  base: DesktopIconId[]
}

export function Win95Desktop(): JSX.Element {
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const updateSettings = useProgramStore((state) => state.updateSettings)
  const addGroup = useProgramStore((state) => state.addGroup)
  const openDialog = useUIStore((state) => state.openDialog)
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const closeQuickSearch = useUIStore((state) => state.closeQuickSearch)
  const windows = useWin95WindowStore((state) => state.windows)
  const activeWindowId = useWin95WindowStore((state) => state.activeWindowId)
  const openMyComputer = useWin95WindowStore((state) => state.openMyComputer)
  const openFind = useWin95WindowStore((state) => state.openFind)
  const closeWindow = useWin95WindowStore((state) => state.closeWindow)
  const activateDesktop = useWin95WindowStore((state) => state.activateDesktop)
  const { scale, logicalViewport, toLogicalDelta, toLogicalPoint } = useWin95Scale()
  const desktopRef = useRef<HTMLDivElement>(null)
  const dragRef = useRef<IconDragState | null>(null)
  const marqueeRef = useRef<MarqueeState | null>(null)
  const typeRef = useRef({ prefix: '', at: 0 })
  const [selection, setSelection] = useState<Win95SelectionState>({ selected: [], focused: null, anchor: null })
  const [hostFocused, setHostFocused] = useState(true)
  const [context, setContext] = useState<{ x: number; y: number; icon?: DesktopIconId } | null>(null)
  const [dragImage, setDragImage] = useState<IconDragState | null>(null)
  const [marquee, setMarquee] = useState<MarqueeState | null>(null)
  const [positions, setPositions] = useState<Record<DesktopIconId, { x: number; y: number }>>(() => ({
    'my-computer': settings.win95DesktopIconPositions['my-computer'] ?? DEFAULT_POSITIONS['my-computer'],
    'network-neighborhood': settings.win95DesktopIconPositions['network-neighborhood'] ?? DEFAULT_POSITIONS['network-neighborhood'],
    'recycle-empty': settings.win95DesktopIconPositions['recycle-empty'] ?? DEFAULT_POSITIONS['recycle-empty']
  }))

  const desktopSize = {
    width: logicalViewport.width,
    height: Math.max(1, logicalViewport.height - WIN95_METRICS.taskbarHeight)
  }
  const spatialItems = DESKTOP_ICONS.map((icon) => ({
    id: icon.id,
    x: positions[icon.id].x,
    y: positions[icon.id].y,
    width: WIN95_METRICS.desktopCellWidth,
    height: WIN95_METRICS.desktopCellHeight
  }))
  const selectedSet = new Set(selection.selected)
  const selectionActive = hostFocused && activeWindowId === null

  useEffect(() => {
    const state = (...args: unknown[]): void => {
      const next = args[0] as HostWindowState
      if (typeof next?.focused === 'boolean') setHostFocused(next.focused)
    }
    window.electronAPI.on(IPC_CHANNELS.WINDOW_STATE_CHANGED, state)
    return () => window.electronAPI.off(IPC_CHANNELS.WINDOW_STATE_CHANGED, state)
  }, [])

  useEffect(() => {
    if (!quickSearchOpen) return
    openFind()
    closeQuickSearch()
  }, [closeQuickSearch, openFind, quickSearchOpen])

  useEffect(() => {
    const valid = new Set(groups.map((group) => `group:${group.id}`))
    for (const entry of windows) if (entry.kind === 'group' && !valid.has(entry.id)) closeWindow(entry.id)
  }, [closeWindow, groups, windows])

  const persistPositions = (next: Record<DesktopIconId, { x: number; y: number }>): void => {
    setPositions(next)
    updateSettings({ win95DesktopIconPositions: next })
  }
  const lineUp = (): void => {
    const ordered = [...DESKTOP_IDS].sort((a, b) => positions[a].y - positions[b].y || positions[a].x - positions[b].x)
    const occupied = new Set<string>()
    const next = { ...positions }
    ordered.forEach((id, index) => {
      let point = snapWin95Position(positions[id], { width: WIN95_METRICS.desktopCellWidth, height: WIN95_METRICS.desktopCellHeight })
      point.x = Math.max(4, Math.min(desktopSize.width - WIN95_METRICS.desktopCellWidth, point.x))
      point.y = Math.max(4, Math.min(desktopSize.height - WIN95_METRICS.desktopCellHeight, point.y))
      while (occupied.has(`${point.x}:${point.y}`)) {
        point = { x: 4 + Math.floor(index / 6) * WIN95_METRICS.desktopCellWidth, y: 4 + (index % 6) * WIN95_METRICS.desktopCellHeight }
        if (!occupied.has(`${point.x}:${point.y}`)) break
        point.y += WIN95_METRICS.desktopCellHeight
      }
      occupied.add(`${point.x}:${point.y}`)
      next[id] = point
    })
    persistPositions(next)
  }
  const autoArrange = (): void => persistPositions({ ...DEFAULT_POSITIONS })

  const openDesktopIcon = (id: DesktopIconId): void => {
    if (id === 'my-computer') openMyComputer()
    else openDialog('unavailable', {
      title: id === 'network-neighborhood' ? 'Network Neighborhood' : 'Recycle Bin',
      message: id === 'network-neighborhood'
        ? 'Network browsing is not available in this application launcher.'
        : 'The launcher does not store deleted files in the Recycle Bin.'
    })
  }

  const selectIcon = (id: DesktopIconId, event: { ctrlKey?: boolean; shiftKey?: boolean }): void => {
    activateDesktop()
    setSelection((current) => selectWin95Item(current, id, DESKTOP_IDS, { ctrl: event.ctrlKey, shift: event.shiftKey }))
  }

  const beginIconDrag = (event: ReactPointerEvent, id: DesktopIconId): void => {
    if (event.button !== 0) return
    event.stopPropagation()
    selectIcon(id, event)
    const currentIds = selectedSet.has(id) ? selection.selected as DesktopIconId[] : [id]
    const origins = Object.fromEntries(currentIds.map((iconId) => [iconId, positions[iconId]]))
    dragRef.current = {
      ids: currentIds,
      startClient: { x: event.clientX, y: event.clientY },
      origins,
      dx: 0,
      dy: 0,
      moved: false
    }
    ;(event.currentTarget as HTMLElement).focus()
  }

  useWin95PointerHandler('pointermove', 'desktop-drag-move', (event) => {
    const current = dragRef.current
    if (!current) return false
    current.dx = toLogicalDelta(event.clientX - current.startClient.x)
    current.dy = toLogicalDelta(event.clientY - current.startClient.y)
    current.moved ||= Math.abs(current.dx) + Math.abs(current.dy) > 3
    if (current.moved) {
      document.documentElement.dataset.win95Dragging = 'true'
      setDragImage({ ...current, origins: { ...current.origins } })
    }
    return current.moved
  })
  useWin95PointerHandler('pointerup', 'desktop-drag-end', () => {
    const current = dragRef.current
    if (!current) return false
    dragRef.current = null
    delete document.documentElement.dataset.win95Dragging
    setDragImage(null)
    if (!current.moved) return false
    document.documentElement.dataset.win95IconDragged = 'true'
    queueMicrotask(() => delete document.documentElement.dataset.win95IconDragged)
    if (settings.autoArrange) { autoArrange(); return true }
    const next = { ...positions }
    current.ids.forEach((id) => {
      const origin = current.origins[id]
      next[id] = {
        x: Math.round(Math.max(0, Math.min(desktopSize.width - WIN95_METRICS.desktopCellWidth, origin.x + current.dx))),
        y: Math.round(Math.max(0, Math.min(desktopSize.height - WIN95_METRICS.desktopCellHeight, origin.y + current.dy)))
      }
    })
    persistPositions(next)
    return true
  })

  useWin95PointerHandler('pointermove', 'desktop-marquee-move', (event) => {
    const current = marqueeRef.current
    const bounds = desktopRef.current?.getBoundingClientRect()
    if (!current || !bounds) return false
    const point = toLogicalPoint(event.clientX, event.clientY, bounds)
    current.rect = normalizeWin95Marquee(current.start, point)
    const hit = itemsInWin95Marquee(spatialItems, current.rect) as DesktopIconId[]
    const selected = [...new Set([...current.base, ...hit])]
    const next = { ...current, rect: { ...current.rect } }
    setMarquee(next)
    setSelection((old) => ({ selected, focused: hit.at(-1) ?? old.focused, anchor: old.anchor }))
    return true
  })
  useWin95PointerHandler('pointerup', 'desktop-marquee-end', () => {
    if (!marqueeRef.current) return false
    marqueeRef.current = null
    setMarquee(null)
    return true
  })

  const desktopMenu = useMemo<Win95MenuItemModel[]>(() => [
    { id: 'arrange', label: '&Arrange Icons', children: [
      { id: 'name', label: 'by &Name', onSelect: lineUp },
      { id: 'type', label: 'by &Type', disabled: true },
      { id: 'sep-auto', separator: true },
      { id: 'auto', label: '&Auto Arrange', checked: settings.autoArrange, onSelect: () => {
        const enabled = !useProgramStore.getState().settings.autoArrange
        updateSettings({ autoArrange: enabled })
        if (enabled) autoArrange()
      } }
    ] },
    { id: 'line-up', label: 'Line &Up Icons', onSelect: lineUp },
    { id: 'sep-1', separator: true },
    { id: 'paste', label: '&Paste', disabled: true },
    { id: 'paste-shortcut', label: 'Paste &Shortcut', disabled: true },
    { id: 'sep-2', separator: true },
    { id: 'new-folder', label: '&New Folder...', onSelect: () => { const id = addGroup('New Folder'); openDialog('groupProperties', { group: useProgramStore.getState().groups.find((group) => group.id === id) }) } },
    { id: 'new-shortcut', label: 'New &Shortcut...', icon: 'new-shortcut', onSelect: () => groups[0]
      ? openDialog('newItem', { groupId: groups[0].id })
      : openDialog('newGroup', { openItemAfterCreate: true }) },
    { id: 'sep-3', separator: true },
    { id: 'properties', label: 'P&roperties', icon: 'properties', onSelect: () => void window.electronAPI.app.openLauncherTools() }
  ], [addGroup, groups, openDialog, positions, settings.autoArrange, updateSettings])

  const iconMenu = useMemo<Win95MenuItemModel[]>(() => [
    { id: 'open', label: '&Open', defaultItem: true, onSelect: () => context?.icon && openDesktopIcon(context.icon) },
    { id: 'sep', separator: true },
    { id: 'properties', label: 'P&roperties', icon: 'properties', onSelect: () => context?.icon && openDialog('unavailable', {
      title: DESKTOP_ICONS.find((entry) => entry.id === context.icon)?.label ?? 'Properties',
      message: 'No additional properties are available for this launcher object.'
    }) }
  ], [context?.icon, openDialog])

  const desktopKey = (event: React.KeyboardEvent): void => {
    const focused = selection.focused ?? selection.selected[0] ?? null
    if (event.ctrlKey && event.key.toLowerCase() === 'a') {
      event.preventDefault(); setSelection(selectWin95All(DESKTOP_IDS)); return
    }
    if (event.key === 'Enter' && focused) { event.preventDefault(); openDesktopIcon(focused as DesktopIconId); return }
    if ((event.key === 'ContextMenu' || (event.shiftKey && event.key === 'F10')) && focused) {
      event.preventDefault(); const id = focused as DesktopIconId
      setContext({ ...positions[id], y: positions[id].y + 35, icon: id }); return
    }
    if (event.key === 'Escape') {
      setContext(null); setSelection({ selected: [], focused: null, anchor: null }); return
    }
    if (event.key === ' ' && focused) {
      event.preventDefault(); setSelection((current) => selectWin95Item(current, focused, DESKTOP_IDS, { ctrl: event.ctrlKey })); return
    }
    if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) {
      event.preventDefault()
      const direction = event.key.replace('Arrow', '').toLowerCase() as 'left' | 'right' | 'up' | 'down'
      const next = findWin95DirectionalItem(spatialItems, focused, direction)
      if (!next) return
      setSelection((current) => event.ctrlKey
        ? { ...current, focused: next }
        : selectWin95Item(current, next, DESKTOP_IDS, { shift: event.shiftKey }))
      return
    }
    if (event.key === 'Home' || event.key === 'End') {
      event.preventDefault(); const id = event.key === 'Home' ? DESKTOP_IDS[0] : DESKTOP_IDS.at(-1)!
      setSelection((current) => selectWin95Item(current, id, DESKTOP_IDS, { shift: event.shiftKey, ctrl: event.ctrlKey })); return
    }
    if (event.key.length === 1 && !event.ctrlKey && !event.altKey && !event.metaKey) {
      const now = Date.now()
      typeRef.current.prefix = now - typeRef.current.at > 1000 ? event.key : typeRef.current.prefix + event.key
      typeRef.current.at = now
      const match = findWin95TypeMatch(DESKTOP_ICONS, typeRef.current.prefix, focused)
      if (match) { event.preventDefault(); setSelection({ selected: [match], focused: match, anchor: match }) }
    }
  }

  return (
    <div
      ref={desktopRef}
      className={`win95-desktop ${selectionActive ? 'selection-active' : 'selection-inactive'}`}
      tabIndex={0}
      onKeyDown={desktopKey}
      onPointerDown={(event) => {
        if (event.button !== 0 || event.target !== event.currentTarget) return
        activateDesktop(); setContext(null); event.currentTarget.focus()
        const bounds = event.currentTarget.getBoundingClientRect()
        const start = toLogicalPoint(event.clientX, event.clientY, bounds)
        const base = event.ctrlKey ? selection.selected as DesktopIconId[] : []
        if (!event.ctrlKey) setSelection({ selected: [], focused: null, anchor: null })
        const next = { start, rect: { x: start.x, y: start.y, width: 0, height: 0 }, base }
        marqueeRef.current = next; setMarquee(next)
      }}
      onContextMenu={(event) => {
        if ((event.target as HTMLElement).closest('.win95-window, .win95-taskbar, .win95-popup-menu, .win95-dialog')) return
        event.preventDefault()
        const root = event.currentTarget.closest('.win95-scale-root')?.getBoundingClientRect()
        const point = toLogicalPoint(event.clientX, event.clientY, root ?? undefined)
        const icon = (event.target as HTMLElement).closest<HTMLElement>('[data-desktop-icon]')?.dataset.desktopIcon as DesktopIconId | undefined
        activateDesktop()
        if (icon && !selectedSet.has(icon)) setSelection({ selected: [icon], focused: icon, anchor: icon })
        setContext({ x: point.x, y: point.y, icon })
      }}
    >
      {DESKTOP_ICONS.map((icon) => {
        const src = getWin95IconSrc(icon.id, 'large', scale)
        const selected = selectedSet.has(icon.id)
        const style = {
          left: positions[icon.id].x,
          top: positions[icon.id].y,
          '--w95-icon-mask': `url("${src}")`
        } as CSSProperties
        return <button
          type="button"
          key={icon.id}
          data-desktop-icon={icon.id}
          className={`win95-desktop-icon ${selected ? 'selected' : ''} ${selection.focused === icon.id ? 'focused' : ''}`}
          style={style}
          onClick={(event) => { event.stopPropagation(); event.currentTarget.focus() }}
          onDoubleClick={() => { if (!document.documentElement.dataset.win95IconDragged) openDesktopIcon(icon.id) }}
          onPointerDown={(event) => beginIconDrag(event, icon.id)}
        >
          <span className="win95-desktop-icon-image"><img src={src} alt="" /></span>
          <span className="win95-desktop-icon-label"><Win95BitmapText text={icon.label} maxWidth={71} wrap color="#ffffff" desktopShadow={!selected} /></span>
        </button>
      })}

      {marquee && <div className="win95-selection-marquee" style={{ left: marquee.rect.x, top: marquee.rect.y, width: marquee.rect.width, height: marquee.rect.height }} />}
      {dragImage?.ids.map((id) => {
        const src = getWin95IconSrc(id, 'large', scale)
        return <div key={id} className="win95-desktop-drag-image" style={{ left: dragImage.origins[id].x + dragImage.dx, top: dragImage.origins[id].y + dragImage.dy }}>
          <img src={src} alt="" /><Win95BitmapText text={DESKTOP_ICONS.find((icon) => icon.id === id)?.label ?? ''} maxWidth={71} color="#ffffff" desktopShadow />
        </div>
      })}

      {windows.map((entry) => {
        const group = entry.groupId ? groups.find((candidate) => candidate.id === entry.groupId) : undefined
        if (entry.kind === 'group' && !group) return null
        return <Win95Window key={entry.id} entry={entry} group={group} desktopSize={desktopSize}
          active={activeWindowId === entry.id} hostFocused={hostFocused} />
      })}

      {context && <Win95PopupMenu items={context.icon ? iconMenu : desktopMenu} x={context.x} y={context.y}
        onClose={() => setContext(null)} roleLabel={context.icon ? 'Desktop icon menu' : 'Desktop menu'} />}
    </div>
  )
}
