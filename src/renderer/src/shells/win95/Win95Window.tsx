import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type JSX,
  type PointerEvent as ReactPointerEvent
} from 'react'
import type { LogicalRect, ProgramGroup } from '@shared/types'
import { getGroupWindowState } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { getWin95IconSrc } from './iconCatalog'
import { useWin95Scale } from './Win95ScaleContext'
import { Win95FolderView, type Win95ViewMode } from './Win95FolderView'
import { Win95FindView } from './Win95FindView'
import { Win95PopupMenu, type Win95MenuItemModel } from './Win95Menu'
import { useWin95InputHandler } from './Win95InputController'
import { constrainWin95Rect, dragWin95Rect, resizeWin95Rect, win95KeyboardResizeEdge, type ResizeEdge } from './geometry'
import { Win95BitmapText } from './bitmapText'
import { Win95Glyph } from './Win95Primitives'
import { useWin95WindowStore, type Win95WindowEntry } from './windowStore'

interface Win95WindowProps {
  entry: Win95WindowEntry
  group?: ProgramGroup
  desktopSize: { width: number; height: number }
  active: boolean
  hostFocused: boolean
}

type KeyboardGeometryMode = {
  kind: 'move' | 'size'
  original: LogicalRect
  current: LogicalRect
  edge?: ResizeEdge
} | null

function groupRect(group: ProgramGroup): LogicalRect {
  const state = getGroupWindowState(group, 'win95')
  return { x: state.x, y: state.y, width: state.width, height: state.height }
}

export function Win95Window({ entry, group, desktopSize, active, hostFocused }: Win95WindowProps): JSX.Element {
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const deleteGroup = useProgramStore((state) => state.deleteGroup)
  const deleteItem = useProgramStore((state) => state.deleteItem)
  const openDialog = useUIStore((state) => state.openDialog)
  const activeDialog = useUIStore((state) => state.activeDialog)
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const focusWindow = useWin95WindowStore((state) => state.focusWindow)
  const openGroup = useWin95WindowStore((state) => state.openGroup)
  const closeWindow = useWin95WindowStore((state) => state.closeWindow)
  const deactivateWindow = useWin95WindowStore((state) => state.deactivateWindow)
  const updateSystemWindow = useWin95WindowStore((state) => state.updateSystemWindow)
  const requestedCommand = useWin95WindowStore((state) => state.requestedCommand)
  const clearWindowCommand = useWin95WindowStore((state) => state.clearWindowCommand)
  const { scale, toLogicalDelta } = useWin95Scale()
  const frameRef = useRef<HTMLDivElement>(null)
  const [viewMode, setViewMode] = useState<Win95ViewMode>('large')
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [findResultCount, setFindResultCount] = useState(0)
  const [findCommand, setFindCommand] = useState<{ type: 'open' | 'select-all'; nonce: number } | null>(null)
  const [folderCommand, setFolderCommand] = useState<{ type: 'select-all'; nonce: number } | null>(null)
  const [menu, setMenu] = useState<{ id: string; x: number; y: number } | null>(null)
  const [menuBarIndex, setMenuBarIndex] = useState<number | null>(null)
  const [systemMenu, setSystemMenu] = useState(false)
  const [keyboardGeometry, setKeyboardGeometry] = useState<KeyboardGeometryMode>(null)
  const [outlineRect, setOutlineRect] = useState<LogicalRect | null>(null)

  const persistedGroupState = group ? getGroupWindowState(group, 'win95') : null
  const systemBounds = entry.systemBounds ?? { x: 42, y: 34, width: 430, height: 300 }
  const initialRect = group ? groupRect(group) : systemBounds
  const [rect, setRect] = useState(() => constrainWin95Rect(initialRect, desktopSize))
  const minimized = group ? !!persistedGroupState?.minimized : !!entry.systemMinimized
  const maximized = group ? !!persistedGroupState?.maximized : !!entry.systemMaximized
  const title = entry.kind === 'find' ? 'Find: All Files' : group?.name ?? 'My Computer'
  const icon = entry.kind === 'find' ? 'find' : group?.icon ?? 'my-computer'

  useEffect(() => {
    if (maximized) return
    const next = group ? groupRect(group) : (entry.systemBounds ?? systemBounds)
    setRect(constrainWin95Rect(next, desktopSize))
  }, [desktopSize.height, desktopSize.width, entry.systemBounds, group?.id,
    persistedGroupState?.height, persistedGroupState?.width, persistedGroupState?.x, persistedGroupState?.y, maximized])

  const persistRect = useCallback((next: LogicalRect) => {
    const constrained = constrainWin95Rect({
      x: Math.round(next.x), y: Math.round(next.y), width: Math.round(next.width), height: Math.round(next.height)
    }, desktopSize)
    setRect(constrained)
    if (group) updateGroupWindowState(group.id, constrained, 'win95')
    else updateSystemWindow(entry.id, { systemBounds: constrained })
  }, [desktopSize, entry.id, group, updateGroupWindowState, updateSystemWindow])

  const beginPointerGeometry = useCallback((event: ReactPointerEvent, kind: 'move' | ResizeEdge) => {
    if (event.button !== 0 || maximized) return
    event.preventDefault()
    event.stopPropagation()
    focusWindow(entry.id)
    const startPoint = { x: event.clientX, y: event.clientY }
    const startRect = rect
    setOutlineRect(startRect)
    const move = (pointer: PointerEvent): void => {
      const dx = toLogicalDelta(pointer.clientX - startPoint.x)
      const dy = toLogicalDelta(pointer.clientY - startPoint.y)
      setOutlineRect(kind === 'move'
        ? dragWin95Rect(startRect, dx, dy, desktopSize)
        : resizeWin95Rect(startRect, kind, dx, dy, desktopSize))
    }
    const end = (pointer: PointerEvent): void => {
      document.removeEventListener('pointermove', move)
      document.removeEventListener('pointerup', end)
      const dx = toLogicalDelta(pointer.clientX - startPoint.x)
      const dy = toLogicalDelta(pointer.clientY - startPoint.y)
      const next = kind === 'move'
        ? dragWin95Rect(startRect, dx, dy, desktopSize)
        : resizeWin95Rect(startRect, kind, dx, dy, desktopSize)
      setOutlineRect(null)
      persistRect(next)
    }
    document.addEventListener('pointermove', move)
    document.addEventListener('pointerup', end)
  }, [desktopSize, entry.id, focusWindow, maximized, persistRect, rect, toLogicalDelta])

  const minimize = useCallback(() => {
    if (group) updateGroupWindowState(group.id, { minimized: true }, 'win95')
    else updateSystemWindow(entry.id, { systemMinimized: true })
    deactivateWindow(entry.id)
    setMenu(null); setSystemMenu(false)
  }, [deactivateWindow, entry.id, group, updateGroupWindowState, updateSystemWindow])

  const restore = useCallback(() => {
    if (group && persistedGroupState) {
      const restored = maximized ? {
        x: persistedGroupState.restoreX ?? rect.x,
        y: persistedGroupState.restoreY ?? rect.y,
        width: persistedGroupState.restoreWidth ?? rect.width,
        height: persistedGroupState.restoreHeight ?? rect.height
      } : rect
      updateGroupWindowState(group.id, { ...restored, maximized: false, minimized: false }, 'win95')
      setRect(constrainWin95Rect(restored, desktopSize))
    } else {
      const restored = maximized ? entry.systemRestoreBounds ?? rect : rect
      updateSystemWindow(entry.id, { systemBounds: restored, systemMaximized: false, systemMinimized: false })
      setRect(constrainWin95Rect(restored, desktopSize))
    }
    focusWindow(entry.id)
    setMenu(null); setSystemMenu(false)
  }, [desktopSize, entry.id, entry.systemRestoreBounds, focusWindow, group, maximized,
    persistedGroupState, rect, updateGroupWindowState, updateSystemWindow])

  const maximize = useCallback(() => {
    if (maximized) { restore(); return }
    if (group) updateGroupWindowState(group.id, {
      restoreX: rect.x, restoreY: rect.y, restoreWidth: rect.width, restoreHeight: rect.height,
      maximized: true, minimized: false
    }, 'win95')
    else updateSystemWindow(entry.id, {
      systemRestoreBounds: rect,
      systemMaximized: true,
      systemMinimized: false
    })
    focusWindow(entry.id)
    setMenu(null); setSystemMenu(false)
  }, [entry.id, focusWindow, group, maximized, rect, restore, updateGroupWindowState, updateSystemWindow])

  const close = useCallback(() => {
    closeWindow(entry.id)
    setMenu(null); setSystemMenu(false)
  }, [closeWindow, entry.id])

  const menuBarIds = ['file', 'edit', 'view', 'help'] as const
  const openMenu = (id: string, button: HTMLElement): void => {
    const root = frameRef.current?.closest('.win95-scale-root')?.getBoundingClientRect()
    const bounds = button.getBoundingClientRect()
    setMenuBarIndex(Math.max(0, menuBarIds.indexOf(id as typeof menuBarIds[number])))
    setSystemMenu(false)
    setMenu({ id, x: (bounds.left - (root?.left ?? 0)) / scale, y: (bounds.bottom - (root?.top ?? 0)) / scale })
  }

  useEffect(() => {
    if (!requestedCommand || requestedCommand.id !== entry.id || minimized || maximized && requestedCommand.command === 'size') return
    const mode = { kind: requestedCommand.command, original: rect, current: rect } as KeyboardGeometryMode
    setKeyboardGeometry(mode)
    setOutlineRect(rect)
    focusWindow(entry.id)
    clearWindowCommand(requestedCommand.nonce)
  }, [clearWindowCommand, entry.id, focusWindow, maximized, minimized, rect, requestedCommand])

  useWin95InputHandler('window', `window-${entry.id}`, (event) => {
    if (!active || minimized || activeDialog !== null || quickSearchOpen) return false
    if (keyboardGeometry) {
      if (event.key === 'Escape' || event.key === 'Enter') {
        if (event.key === 'Enter') persistRect(keyboardGeometry.current)
        setKeyboardGeometry(null)
        setOutlineRect(null)
        return true
      }
      const arrows = ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'] as const
      if (!arrows.includes(event.key as typeof arrows[number])) return false
      const key = event.key as typeof arrows[number]
      const amount = event.shiftKey ? 8 : 1
      const dx = key === 'ArrowLeft' ? -amount : key === 'ArrowRight' ? amount : 0
      const dy = key === 'ArrowUp' ? -amount : key === 'ArrowDown' ? amount : 0
      setKeyboardGeometry((current) => {
        if (!current) return null
        const edge = current.kind === 'size' ? win95KeyboardResizeEdge(current.edge, key) : current.edge
        const next = current.kind === 'move'
          ? dragWin95Rect(current.current, dx, dy, desktopSize)
          : resizeWin95Rect(current.current, edge ?? 'se', dx, dy, desktopSize)
        setOutlineRect(next)
        return { ...current, current: next, edge }
      })
      return true
    }
    if (event.key === 'Alt' && !event.altKey) {
      setMenu(null); setSystemMenu(false); setMenuBarIndex(0)
      frameRef.current?.querySelector<HTMLElement>('[data-menu=file]')?.focus()
      return true
    }
    if (menuBarIndex !== null && !event.altKey) {
      if (event.key === 'Escape') { setMenu(null); setMenuBarIndex(null); return true }
      if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
        const delta = event.key === 'ArrowRight' ? 1 : -1
        const next = (menuBarIndex + delta + menuBarIds.length) % menuBarIds.length
        setMenuBarIndex(next)
        const button = frameRef.current?.querySelector<HTMLElement>(`[data-menu=${menuBarIds[next]}]`)
        button?.focus()
        if (menu && button) openMenu(menuBarIds[next], button)
        return true
      }
      if (event.key === 'ArrowDown' || event.key === 'Enter') {
        const id = menuBarIds[menuBarIndex]
        const button = frameRef.current?.querySelector<HTMLElement>(`[data-menu=${id}]`)
        if (button) openMenu(id, button)
        return true
      }
    }
    if (event.altKey && event.key === ' ') { setSystemMenu((open) => !open); setMenu(null); return true }
    if (event.altKey && event.key === 'F4') { close(); return true }
    if (event.altKey && ['f','e','v','h'].includes(event.key.toLowerCase())) {
      const id = ({ f: 'file', e: 'edit', v: 'view', h: 'help' } as const)[event.key.toLowerCase() as 'f'|'e'|'v'|'h']
      const button = frameRef.current?.querySelector<HTMLElement>(`[data-menu=${id}]`)
      if (button) openMenu(id, button)
      return !!button
    }
    if (event.key === 'ContextMenu' || (event.shiftKey && event.key === 'F10')) {
      const selected = frameRef.current?.querySelector<HTMLElement>('.win95-folder-item.selected')
      selected?.dispatchEvent(new MouseEvent('contextmenu', {
        bubbles: true,
        clientX: selected.getBoundingClientRect().left,
        clientY: selected.getBoundingClientRect().bottom
      }))
      return !!selected
    }
    return false
  }, active && !minimized)

  const openSelected = useCallback(async (): Promise<void> => {
    if (!selectedId) return
    if (entry.kind === 'my-computer') {
      const selectedGroup = groups.find((candidate) => candidate.id === selectedId)
      if (selectedGroup) {
        updateGroupWindowState(selectedGroup.id, { minimized: false }, 'win95')
        openGroup(selectedGroup.id)
      }
      return
    }
    const item = group?.items.find((candidate) => candidate.id === selectedId)
    if (!item) return
    const result = await window.electronAPI.program.launch(item)
    if (!result.success) openDialog('unavailable', { title: item.name, message: result.error ?? `Windows cannot find '${item.path}'.` })
    else if (settings.minimizeOnUse) void window.electronAPI.window.minimize()
  }, [entry.kind, group?.items, groups, openDialog, openGroup, selectedId, settings.minimizeOnUse, updateGroupWindowState])

  const deleteSelected = useCallback((): void => {
    if (!selectedId) return
    if (entry.kind === 'my-computer') {
      const selectedGroup = groups.find((candidate) => candidate.id === selectedId)
      if (selectedGroup) openDialog('confirm', { confirmOptions: {
        title: 'Confirm Folder Delete',
        message: `Are you sure you want to remove '${selectedGroup.name}' and all of its contents?`,
        onConfirm: () => { deleteGroup(selectedGroup.id); closeWindow(`group:${selectedGroup.id}`) }
      } })
      return
    }
    const item = group?.items.find((candidate) => candidate.id === selectedId)
    if (group && item) openDialog('confirm', { confirmOptions: {
      title: 'Confirm File Delete', message: `Are you sure you want to remove '${item.name}'?`,
      onConfirm: () => deleteItem(group.id, item.id)
    } })
  }, [closeWindow, deleteGroup, deleteItem, entry.kind, group, groups, openDialog, selectedId])

  const menuItems = useMemo<Record<string, Win95MenuItemModel[]>>(() => {
    if (entry.kind === 'find') return {
      file: [
        { id: 'open', label: '&Open', disabled: !selectedId, onSelect: () => setFindCommand({ type: 'open', nonce: Date.now() }) },
        { id: 'sep', separator: true },
        { id: 'close', label: '&Close', defaultItem: true, onSelect: close }
      ],
      edit: [
        { id: 'cut', label: 'Cu&t', disabled: true },
        { id: 'copy', label: '&Copy', disabled: true },
        { id: 'sep', separator: true },
        { id: 'select-all', label: 'Select &All', disabled: findResultCount === 0, onSelect: () => setFindCommand({ type: 'select-all', nonce: Date.now() }) }
      ],
      view: [
        { id: 'details', label: '&Details', checked: true },
        { id: 'sep', separator: true },
        { id: 'status', label: 'Status &Bar', checked: true }
      ],
      help: [
        { id: 'topics', label: '&Help Topics', onSelect: () => openDialog('help') },
        { id: 'sep', separator: true },
        { id: 'about', label: '&About Gosh 95...', onSelect: () => openDialog('about') }
      ]
    }
    return {
      file: [
        { id: 'open', label: '&Open', disabled: !selectedId, onSelect: () => { void openSelected() } },
        { id: 'new', label: '&New Program...', onSelect: () => group ? openDialog('newItem', { groupId: group.id }) : openDialog('newGroup') },
        { id: 'sep-1', separator: true },
        { id: 'delete', label: '&Delete', disabled: !selectedId, onSelect: deleteSelected },
        { id: 'properties', label: 'P&roperties', onSelect: () => group ? openDialog('groupProperties', { group }) : void window.electronAPI.app.openLauncherTools() },
        { id: 'sep-2', separator: true },
        { id: 'close', label: '&Close', onSelect: close }
      ],
      edit: [
        { id: 'undo', label: '&Undo', disabled: true },
        { id: 'sep-1', separator: true },
        { id: 'cut', label: 'Cu&t', disabled: true },
        { id: 'copy', label: '&Copy', disabled: true },
        { id: 'paste', label: '&Paste', disabled: true },
        { id: 'sep-2', separator: true },
        { id: 'select-all', label: 'Select &All', disabled: (group?.items.length ?? groups.length) === 0, onSelect: () => setFolderCommand({ type: 'select-all', nonce: Date.now() }) }
      ],
      view: [
        { id: 'large', label: 'Lar&ge Icons', checked: viewMode === 'large', onSelect: () => setViewMode('large') },
        { id: 'small', label: 'S&mall Icons', checked: viewMode === 'small', onSelect: () => setViewMode('small') },
        { id: 'list', label: '&List', checked: viewMode === 'list', onSelect: () => setViewMode('list') },
        { id: 'details', label: '&Details', checked: viewMode === 'details', onSelect: () => setViewMode('details') },
        { id: 'sep-1', separator: true },
        { id: 'status', label: 'Status &Bar', checked: true }
      ],
      help: [
        { id: 'topics', label: '&Help Topics', onSelect: () => openDialog('help') },
        { id: 'sep-1', separator: true },
        { id: 'about', label: '&About Gosh 95...', onSelect: () => openDialog('about') }
      ]
    }
  }, [close, deleteSelected, entry.kind, findResultCount, group, groups.length, openDialog, openSelected, selectedId, viewMode])

  const beginKeyboardGeometry = (kind: 'move' | 'size'): void => {
    const mode: KeyboardGeometryMode = { kind, original: rect, current: rect }
    setKeyboardGeometry(mode)
    setOutlineRect(rect)
  }
  const systemItems: Win95MenuItemModel[] = [
    { id: 'restore', label: '&Restore', disabled: !maximized && !minimized, onSelect: restore },
    { id: 'move', label: '&Move', disabled: maximized, onSelect: () => beginKeyboardGeometry('move') },
    { id: 'size', label: '&Size', disabled: maximized, onSelect: () => beginKeyboardGeometry('size') },
    { id: 'minimize', label: 'Mi&nimize', disabled: minimized, onSelect: minimize },
    { id: 'maximize', label: 'Ma&ximize', disabled: maximized, onSelect: maximize },
    { id: 'sep', separator: true },
    { id: 'close', label: '&Close', defaultItem: true, onSelect: close }
  ]

  if (minimized) return <></>
  const drawnRect = maximized ? { x: 0, y: 0, width: desktopSize.width, height: desktopSize.height } : rect
  const count = entry.kind === 'find' ? findResultCount : group?.items.length ?? useProgramStore.getState().groups.length

  return (
    <>
    <div
      ref={frameRef}
      className={`win95-window ${active && hostFocused ? 'active' : 'inactive'} ${maximized ? 'maximized' : ''}`}
      style={{ left: drawnRect.x, top: drawnRect.y, width: drawnRect.width, height: drawnRect.height, zIndex: entry.zIndex }}
      onPointerDown={() => focusWindow(entry.id)}
    >
      <div className="win95-caption" onPointerDown={(event) => beginPointerGeometry(event, 'move')} onDoubleClick={maximize}
        onContextMenu={(event) => { event.preventDefault(); setSystemMenu(true); setMenu(null) }}>
        <button className="win95-caption-icon" type="button" aria-label={`${title} system menu`}
          onClick={(event) => { event.stopPropagation(); setSystemMenu((open) => !open); setMenu(null) }}
          onDoubleClick={(event) => { event.stopPropagation(); close() }}>
          <img src={getWin95IconSrc(icon, 'small', scale)} alt="" />
        </button>
        <span className="win95-caption-title"><Win95BitmapText text={title} bold color={active && hostFocused ? '#ffffff' : '#c0c0c0'} maxWidth={Math.max(1, drawnRect.width - 94)} /></span>
        <div className="win95-caption-controls" onContextMenu={(event) => { event.preventDefault(); event.stopPropagation(); setSystemMenu(true); setMenu(null) }}>
          <button type="button" aria-label="Minimize" onClick={(event) => { event.stopPropagation(); minimize() }}><Win95Glyph name="minimize" /></button>
          <button type="button" aria-label={maximized ? 'Restore' : 'Maximize'} onClick={(event) => { event.stopPropagation(); maximized ? restore() : maximize() }}><Win95Glyph name={maximized ? 'restore' : 'maximize'} /></button>
          <button type="button" aria-label="Close" onClick={(event) => { event.stopPropagation(); close() }}><Win95Glyph name="close" /></button>
        </div>
      </div>
      <div className="win95-window-menubar">
        {[['file','&File'],['edit','&Edit'],['view','&View'],['help','&Help']].map(([id,label]) => (
          <button type="button" key={id} data-menu={id}
            className={`${menu?.id === id ? 'pressed' : ''} ${menuBarIndex === menuBarIds.indexOf(id as typeof menuBarIds[number]) ? 'menu-focus' : ''}`}
            onPointerDown={(event) => { event.stopPropagation(); openMenu(id, event.currentTarget) }}
            onPointerEnter={(event) => { if (menu) openMenu(id, event.currentTarget) }}>
            <Win95BitmapText text={label} />
          </button>
        ))}
      </div>
      <div className="win95-window-client">
        {entry.kind === 'find'
          ? <Win95FindView command={findCommand} onResultCount={setFindResultCount} onSelectionChange={setSelectedId} />
          : <Win95FolderView kind={entry.kind} group={group} viewMode={viewMode} command={folderCommand}
            selectionActive={active && hostFocused} onSelectionChange={setSelectedId} />}
      </div>
      <div className="win95-statusbar"><span><Win95BitmapText text={`${count} object${count === 1 ? '' : 's'}`} /></span>{!maximized && <span className="win95-size-grip"><Win95Glyph name="size-grip" /></span>}</div>
      {!maximized && (['n','s','e','w','ne','nw','se','sw'] as ResizeEdge[]).map((edge) => (
        <div key={edge} className={`win95-resize win95-resize-${edge}`} onPointerDown={(event) => beginPointerGeometry(event, edge)} />
      ))}
      {menu && <Win95PopupMenu items={menuItems[menu.id] ?? []} x={menu.x} y={menu.y}
        onClose={() => { setMenu(null); setMenuBarIndex(null) }} roleLabel={`${menu.id} menu`} />}
      {systemMenu && <Win95PopupMenu items={systemItems} x={drawnRect.x + 3} y={drawnRect.y + 18} onClose={() => setSystemMenu(false)} roleLabel={`${title} system menu`} />}
    </div>
    {outlineRect && <div className="win95-window-outline" aria-hidden="true" style={{
      left: outlineRect.x, top: outlineRect.y, width: outlineRect.width, height: outlineRect.height, zIndex: entry.zIndex + 5000
    }} />}
    </>
  )
}
