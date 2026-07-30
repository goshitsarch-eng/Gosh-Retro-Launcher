import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type DragEvent,
  type JSX,
  type PointerEvent as ReactPointerEvent
} from 'react'
import type { ProgramGroup, ProgramItem } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { getWin95IconSrc } from './iconCatalog'
import { useWin95Scale } from './Win95ScaleContext'
import { useWin95WindowStore } from './windowStore'
import { Win95PopupMenu, type Win95MenuItemModel } from './Win95Menu'
import { Win95BitmapText } from './bitmapText'
import { Win95Scrollbar } from './Win95Scrollbar'
import { useWin95PointerHandler } from './Win95InputController'
import { clampWin95Scroll } from './scrollbarState'
import { layoutWin95ListView, resizeWin95ReportColumn, win95PageSelectionIndex } from './listViewState'
import {
  findWin95DirectionalItem,
  findWin95TypeMatch,
  itemsInWin95Marquee,
  normalizeWin95Marquee,
  selectWin95All,
  selectWin95Item,
  type Win95MarqueeRect,
  type Win95SelectionState
} from './selectionState'

export type Win95ViewMode = 'large' | 'small' | 'list' | 'details'

interface Win95FolderViewProps {
  kind: 'my-computer' | 'group'
  group?: ProgramGroup
  viewMode: Win95ViewMode
  onSelectionChange?: (itemId: string | null) => void
  command?: { type: 'select-all'; nonce: number } | null
  selectionActive?: boolean
}

interface DragState {
  id: string
  startClient: { x: number; y: number }
  origin: { x: number; y: number }
  dx: number
  dy: number
  moved: boolean
}
interface MarqueeState { start: { x: number; y: number }; rect: Win95MarqueeRect; base: string[] }

export function Win95FolderView({ kind, group, viewMode, onSelectionChange, command, selectionActive = true }: Win95FolderViewProps): JSX.Element {
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const addItem = useProgramStore((state) => state.addItem)
  const deleteItem = useProgramStore((state) => state.deleteItem)
  const updateWin95ItemPosition = useProgramStore((state) => state.updateWin95ItemPosition)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const openDialog = useUIStore((state) => state.openDialog)
  const openGroup = useWin95WindowStore((state) => state.openGroup)
  const { scale, toLogicalDelta, toLogicalPoint } = useWin95Scale()
  const outerRef = useRef<HTMLDivElement>(null)
  const viewportRef = useRef<HTMLDivElement>(null)
  const dragRef = useRef<DragState | null>(null)
  const marqueeRef = useRef<MarqueeState | null>(null)
  const typeRef = useRef({ prefix: '', at: 0 })
  const [size, setSize] = useState({ width: 320, height: 200 })
  const [scroll, setScroll] = useState({ x: 0, y: 0 })
  const [reportWidths, setReportWidths] = useState({ name: 220, type: 110, location: 180 })
  const [selection, setSelection] = useState<Win95SelectionState>({ selected: [], focused: null, anchor: null })
  const [context, setContext] = useState<{ x: number; y: number; targetId?: string } | null>(null)
  const [marquee, setMarquee] = useState<MarqueeState | null>(null)
  const [dragImage, setDragImage] = useState<DragState | null>(null)

  const entries: Array<ProgramGroup | ProgramItem> = kind === 'my-computer' ? groups : group?.items ?? []
  const ids = entries.map((entry) => entry.id)
  const manualPositions = Object.fromEntries(entries.map((entry) => [entry.id, 'items' in entry ? undefined : entry.win95Position]))
  const scrollbar = 16

  const computed = useMemo(() => {
    let viewport = { width: size.width, height: size.height }
    let layout = layoutWin95ListView(ids, viewMode, viewport, manualPositions, settings.autoArrange, reportWidths)
    let vertical = layout.contentHeight > viewport.height
    let horizontal = layout.contentWidth > viewport.width
    viewport = {
      width: Math.max(1, size.width - (vertical ? scrollbar : 0)),
      height: Math.max(1, size.height - (horizontal ? scrollbar : 0))
    }
    layout = layoutWin95ListView(ids, viewMode, viewport, manualPositions, settings.autoArrange, reportWidths)
    vertical = layout.contentHeight > viewport.height
    horizontal = layout.contentWidth > viewport.width
    if (vertical && viewport.width === size.width) viewport.width = Math.max(1, viewport.width - scrollbar)
    if (horizontal && viewport.height === size.height) viewport.height = Math.max(1, viewport.height - scrollbar)
    layout = layoutWin95ListView(ids, viewMode, viewport, manualPositions, settings.autoArrange, reportWidths)
    return { layout, viewport, vertical, horizontal }
  }, [ids.join('|'), manualPositions, reportWidths, settings.autoArrange, size.height, size.width, viewMode])

  useEffect(() => {
    const element = outerRef.current
    if (!element) return
    const measure = (): void => setSize({ width: element.clientWidth, height: element.clientHeight })
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(element)
    return () => observer.disconnect()
  }, [])
  useEffect(() => {
    setScroll((current) => ({
      x: clampWin95Scroll(current.x, computed.layout.contentWidth, computed.viewport.width),
      y: clampWin95Scroll(current.y, computed.layout.contentHeight, computed.viewport.height)
    }))
  }, [computed.layout.contentHeight, computed.layout.contentWidth, computed.viewport.height, computed.viewport.width])
  useEffect(() => {
    const focused = selection.focused ?? selection.selected[0] ?? null
    onSelectionChange?.(focused)
  }, [onSelectionChange, selection.focused, selection.selected])
  useEffect(() => {
    if (command?.type === 'select-all') setSelection(selectWin95All(ids))
  }, [command?.nonce])
  useEffect(() => {
    const valid = new Set(ids)
    setSelection((current) => ({
      selected: current.selected.filter((id) => valid.has(id)),
      focused: current.focused && valid.has(current.focused) ? current.focused : null,
      anchor: current.anchor && valid.has(current.anchor) ? current.anchor : null
    }))
  }, [ids.join('|')])

  const openEntry = useCallback(async (entry: ProgramGroup | ProgramItem): Promise<void> => {
    if ('items' in entry) {
      updateGroupWindowState(entry.id, { minimized: false }, 'win95')
      openGroup(entry.id)
      return
    }
    const result = await window.electronAPI.program.launch(entry)
    if (!result.success) {
      openDialog('unavailable', { title: entry.name, message: result.error ?? `Windows cannot find '${entry.path}'.` })
      return
    }
    if (settings.minimizeOnUse) void window.electronAPI.window.minimize()
  }, [openDialog, openGroup, settings.minimizeOnUse, updateGroupWindowState])

  const reveal = (id: string): void => {
    const item = computed.layout.items.find((candidate) => candidate.id === id)
    if (!item) return
    setScroll((current) => ({
      x: item.x < current.x ? item.x : item.x + item.width > current.x + computed.viewport.width ? item.x + item.width - computed.viewport.width : current.x,
      y: item.y < current.y + (viewMode === 'details' ? 18 : 0) ? Math.max(0, item.y - (viewMode === 'details' ? 18 : 0)) : item.y + item.height > current.y + computed.viewport.height ? item.y + item.height - computed.viewport.height : current.y
    }))
  }
  const choose = (id: string, modifiers: { ctrl?: boolean; shift?: boolean } = {}): void => {
    setSelection((current) => selectWin95Item(current, id, ids, modifiers))
    reveal(id)
  }
  const deleteSelected = (): void => {
    if (kind !== 'group' || !group || !selection.selected.length) return
    const selectedEntries = entries.filter((entry): entry is ProgramItem => !('items' in entry) && selection.selected.includes(entry.id))
    if (!selectedEntries.length) return
    openDialog('confirm', { confirmOptions: {
      title: 'Confirm File Delete',
      message: selectedEntries.length === 1
        ? `Are you sure you want to remove '${selectedEntries[0].name}'?`
        : `Are you sure you want to remove these ${selectedEntries.length} items?`,
      onConfirm: () => selectedEntries.forEach((item) => deleteItem(group.id, item.id))
    } })
  }

  const keyDown = (event: React.KeyboardEvent): void => {
    if (event.ctrlKey && event.key.toLowerCase() === 'a') { event.preventDefault(); setSelection(selectWin95All(ids)); return }
    const focused = selection.focused ?? selection.selected[0] ?? null
    const selectedIndex = Math.max(0, ids.indexOf(focused ?? ''))
    if (event.key === 'Enter' && focused) { event.preventDefault(); const entry = entries.find((candidate) => candidate.id === focused); if (entry) void openEntry(entry); return }
    if (event.key === 'Delete') { event.preventDefault(); deleteSelected(); return }
    if ((event.shiftKey && event.key === 'F10') || event.key === 'ContextMenu') {
      event.preventDefault()
      const item = computed.layout.items.find((candidate) => candidate.id === focused)
      setContext({ x: (item?.x ?? 2) - scroll.x + 18, y: (item?.y ?? 2) - scroll.y + 18, targetId: focused ?? undefined })
      return
    }
    let nextId: string | null = null
    if (['ArrowRight', 'ArrowLeft', 'ArrowDown', 'ArrowUp'].includes(event.key)) {
      const direction = event.key.replace('Arrow', '').toLowerCase() as 'left' | 'right' | 'down' | 'up'
      nextId = findWin95DirectionalItem(computed.layout.items, focused, direction)
    } else if (event.key === 'Home') nextId = ids[0] ?? null
    else if (event.key === 'End') nextId = ids.at(-1) ?? null
    else if (event.key === 'PageDown' || event.key === 'PageUp') {
      const index = win95PageSelectionIndex(selectedIndex, event.key === 'PageDown' ? 1 : -1, computed.layout.rowsPerPage, ids.length)
      nextId = ids[index] ?? null
    } else if (event.key.length === 1 && !event.ctrlKey && !event.altKey && !event.metaKey) {
      const now = Date.now()
      typeRef.current.prefix = now - typeRef.current.at > 1000 ? event.key : typeRef.current.prefix + event.key
      typeRef.current.at = now
      nextId = findWin95TypeMatch(entries.map((entry) => ({ id: entry.id, label: entry.name })), typeRef.current.prefix, focused)
    } else return
    if (!nextId) return
    event.preventDefault()
    if (event.ctrlKey) setSelection((current) => ({ ...current, focused: nextId }))
    else choose(nextId, { shift: event.shiftKey })
  }

  const drop = useCallback(async (event: DragEvent<HTMLDivElement>) => {
    if (kind !== 'group' || !group) return
    event.preventDefault()
    for (const file of Array.from(event.dataTransfer.files)) {
      const filePath = (file as File & { path?: string }).path
      if (!filePath) continue
      try {
        const info = await window.electronAPI.app.getInfo(filePath)
        addItem(group.id, { name: info.name, path: info.path, icon: info.icon ?? 'application', workingDir: info.workingDir ?? '' })
      } catch (error) { console.error('Could not add dropped application:', error) }
    }
  }, [addItem, group, kind])

  const beginItemDrag = (event: ReactPointerEvent, id: string): void => {
    if (event.button !== 0 || settings.autoArrange || kind !== 'group' || !group || (viewMode !== 'large' && viewMode !== 'small')) return
    const item = computed.layout.items.find((candidate) => candidate.id === id)
    if (!item) return
    dragRef.current = { id, startClient: { x: event.clientX, y: event.clientY }, origin: { x: item.x, y: item.y }, dx: 0, dy: 0, moved: false }
  }
  useWin95PointerHandler('pointermove', `folder-item-drag-${group?.id ?? kind}`, (event) => {
    const current = dragRef.current
    if (!current) return false
    current.dx = toLogicalDelta(event.clientX - current.startClient.x)
    current.dy = toLogicalDelta(event.clientY - current.startClient.y)
    current.moved ||= Math.abs(current.dx) + Math.abs(current.dy) > 3
    if (current.moved) setDragImage({ ...current })
    return current.moved
  })
  useWin95PointerHandler('pointerup', `folder-item-drop-${group?.id ?? kind}`, () => {
    const current = dragRef.current
    if (!current) return false
    dragRef.current = null; setDragImage(null)
    if (!current.moved || !group) return false
    updateWin95ItemPosition(group.id, current.id, {
      x: Math.round(Math.max(0, current.origin.x + current.dx)),
      y: Math.round(Math.max(viewMode === 'details' ? 18 : 0, current.origin.y + current.dy))
    })
    return true
  })

  useWin95PointerHandler('pointermove', `folder-marquee-${group?.id ?? kind}`, (event) => {
    const current = marqueeRef.current
    const bounds = viewportRef.current?.getBoundingClientRect()
    if (!current || !bounds) return false
    const point = toLogicalPoint(event.clientX, event.clientY, bounds)
    const contentPoint = { x: point.x + scroll.x, y: point.y + scroll.y }
    current.rect = normalizeWin95Marquee(current.start, contentPoint)
    const hit = itemsInWin95Marquee(computed.layout.items, current.rect)
    const selected = [...new Set([...current.base, ...hit])]
    setSelection((old) => ({ selected, focused: hit.at(-1) ?? old.focused, anchor: old.anchor }))
    setMarquee({ ...current, rect: { ...current.rect } })
    return true
  })
  useWin95PointerHandler('pointerup', `folder-marquee-end-${group?.id ?? kind}`, () => {
    if (!marqueeRef.current) return false
    marqueeRef.current = null; setMarquee(null); return true
  })

  const target = context?.targetId ? entries.find((entry) => entry.id === context.targetId) : undefined
  const contextItems = useMemo<Win95MenuItemModel[]>(() => {
    if (target) return [
      { id: 'open', label: '&Open', defaultItem: true, onSelect: () => { void openEntry(target) } },
      { id: 'sep-1', separator: true },
      ...(kind === 'group' && group && !('items' in target) ? [
        { id: 'delete', label: '&Delete', onSelect: deleteSelected },
        { id: 'properties', label: 'P&roperties', icon: 'properties', onSelect: () => openDialog('itemProperties', { groupId: group.id, item: target }) }
      ] : [
        { id: 'properties', label: 'P&roperties', icon: 'properties', onSelect: () => openDialog('groupProperties', { group: target as ProgramGroup }) }
      ])
    ]
    if (kind === 'group' && group) return [
      { id: 'new-program', label: '&New Program...', icon: 'new-shortcut', onSelect: () => openDialog('newItem', { groupId: group.id }) },
      { id: 'new-url', label: 'New &URL...', onSelect: () => openDialog('newUrl', { groupId: group.id }) },
      { id: 'sep', separator: true },
      { id: 'select-all', label: 'Select &All', disabled: !entries.length, onSelect: () => setSelection(selectWin95All(ids)) }
    ]
    return [
      { id: 'new-folder', label: '&New Folder...', onSelect: () => openDialog('newGroup') },
      { id: 'properties', label: 'P&roperties', icon: 'properties', onSelect: () => void window.electronAPI.app.openLauncherTools() }
    ]
  }, [entries.length, group, kind, openDialog, openEntry, selection.selected, target])

  const selectedSet = new Set(selection.selected)
  const itemById = new Map(computed.layout.items.map((item) => [item.id, item]))
  const showVertical = computed.vertical
  const showHorizontal = computed.horizontal

  return (
    <div ref={outerRef} className={`win95-folder-view view-${viewMode}`} role="listbox" tabIndex={0}
      aria-label={kind === 'my-computer' ? 'My Computer' : group?.name}
      aria-multiselectable="true" onKeyDown={keyDown}
      onWheel={(event) => {
        if (showVertical && event.deltaY) { event.preventDefault(); setScroll((current) => ({ ...current, y: clampWin95Scroll(current.y + Math.sign(event.deltaY) * 48, computed.layout.contentHeight, computed.viewport.height) })) }
        else if (showHorizontal && (event.deltaX || event.deltaY)) { event.preventDefault(); setScroll((current) => ({ ...current, x: clampWin95Scroll(current.x + Math.sign(event.deltaX || event.deltaY) * 80, computed.layout.contentWidth, computed.viewport.width) })) }
      }}
      onContextMenu={(event) => {
        event.preventDefault(); event.stopPropagation()
        const root = event.currentTarget.closest('.win95-scale-root')?.getBoundingClientRect()
        const point = toLogicalPoint(event.clientX, event.clientY, root ?? undefined)
        const targetElement = (event.target as HTMLElement).closest<HTMLElement>('[data-entry-id]')
        const targetId = targetElement?.dataset.entryId
        if (targetId && !selectedSet.has(targetId)) setSelection({ selected: [targetId], focused: targetId, anchor: targetId })
        setContext({ x: point.x, y: point.y, targetId })
      }}
      onDragOver={(event) => { if (kind === 'group') { event.preventDefault(); event.dataTransfer.dropEffect = 'copy' } }}
      onDrop={drop}>
      <div ref={viewportRef} className="win95-list-viewport" style={{ width: computed.viewport.width, height: computed.viewport.height }}
        onPointerDown={(event) => {
          if (event.button !== 0 || (event.target as HTMLElement).closest('[data-entry-id], .win95-report-header')) return
          event.currentTarget.closest<HTMLElement>('.win95-folder-view')?.focus()
          setContext(null)
          const bounds = event.currentTarget.getBoundingClientRect()
          const point = toLogicalPoint(event.clientX, event.clientY, bounds)
          const start = { x: point.x + scroll.x, y: point.y + scroll.y }
          const base = event.ctrlKey ? selection.selected : []
          if (!event.ctrlKey) setSelection({ selected: [], focused: null, anchor: null })
          const next = { start, rect: { x: start.x, y: start.y, width: 0, height: 0 }, base }
          marqueeRef.current = next; setMarquee(next)
        }}>
        {viewMode === 'details' && <ReportHeader widths={reportWidths} scrollX={scroll.x} onResize={(column, delta) => setReportWidths((current) => ({ ...current, [column]: resizeWin95ReportColumn(current[column], delta) }))} />}
        <div className="win95-list-content" style={{ width: computed.layout.contentWidth, height: computed.layout.contentHeight }}>
          {entries.map((entry) => {
            const layout = itemById.get(entry.id)
            if (!layout) return null
            const isGroup = 'items' in entry
            const icon = isGroup ? 'folder' : entry.icon
            const src = getWin95IconSrc(icon, viewMode === 'large' ? 'large' : 'small', scale)
            const selected = selectedSet.has(entry.id)
            const style = {
              left: layout.x - scroll.x,
              top: layout.y - scroll.y,
              width: layout.width,
              height: layout.height,
              '--w95-icon-mask': `url("${src}")`,
              ...(viewMode === 'details' ? { gridTemplateColumns: `18px ${reportWidths.name - 18}px ${reportWidths.type}px ${reportWidths.location}px` } : {})
            } as CSSProperties
            return <button type="button" key={entry.id} data-entry-id={entry.id}
              className={`win95-folder-item ${selected ? 'selected' : ''} ${selection.focused === entry.id ? 'focused' : ''}`}
              style={style} role="option" aria-selected={selected}
              onPointerDown={(event) => {
                event.stopPropagation()
                choose(entry.id, { ctrl: event.ctrlKey, shift: event.shiftKey })
                beginItemDrag(event, entry.id)
              }}
              onClick={(event) => event.stopPropagation()}
              onDoubleClick={() => void openEntry(entry)}>
              <span className="win95-folder-item-icon"><img src={src} alt="" /></span>
              <span className="win95-folder-item-name"><Win95BitmapText text={entry.name} maxWidth={Math.max(20, viewMode === 'large' ? layout.width - 4 : reportWidths.name - 22)} wrap={viewMode === 'large'} color={selected && selectionActive ? '#ffffff' : '#000000'} /></span>
              {viewMode === 'details' && <>
                <span className="win95-folder-item-type"><Win95BitmapText text={isGroup ? 'File Folder' : 'Application'} color={selected && selectionActive ? '#ffffff' : '#000000'} /></span>
                <span className="win95-folder-item-location"><Win95BitmapText text={isGroup ? 'My Computer' : group?.name ?? ''} color={selected && selectionActive ? '#ffffff' : '#000000'} /></span>
              </>}
            </button>
          })}
          {marquee && <div className="win95-selection-marquee list" style={{ left: marquee.rect.x - scroll.x, top: marquee.rect.y - scroll.y, width: marquee.rect.width, height: marquee.rect.height }} />}
          {dragImage && (() => {
            const entry = entries.find((candidate) => candidate.id === dragImage.id)
            if (!entry) return null
            const src = getWin95IconSrc('items' in entry ? 'folder' : entry.icon, viewMode === 'large' ? 'large' : 'small', scale)
            return <div className={`win95-folder-drag-image ${viewMode}`} style={{ left: dragImage.origin.x + dragImage.dx - scroll.x, top: dragImage.origin.y + dragImage.dy - scroll.y }}><img src={src} alt="" /><Win95BitmapText text={entry.name} /></div>
          })()}
        </div>
      </div>
      {showVertical && <Win95Scrollbar orientation="vertical" value={scroll.y} viewportSize={computed.viewport.height} contentSize={computed.layout.contentHeight}
        length={computed.viewport.height} onChange={(y) => setScroll((current) => ({ ...current, y }))} lineSize={viewMode === 'details' ? 19 : 20} />}
      {showHorizontal && <Win95Scrollbar orientation="horizontal" value={scroll.x} viewportSize={computed.viewport.width} contentSize={computed.layout.contentWidth}
        length={computed.viewport.width} onChange={(x) => setScroll((current) => ({ ...current, x }))} lineSize={80} />}
      {showHorizontal && showVertical && <div className="win95-scroll-corner" />}
      {context && <Win95PopupMenu items={contextItems} x={context.x} y={context.y} onClose={() => setContext(null)} roleLabel="Folder context menu" />}
    </div>
  )
}

function ReportHeader({ widths, scrollX, onResize }: {
  widths: { name: number; type: number; location: number }
  scrollX: number
  onResize: (column: 'name' | 'type' | 'location', delta: number) => void
}): JSX.Element {
  const drag = useRef<{ column: 'name' | 'type' | 'location'; x: number } | null>(null)
  const { toLogicalDelta } = useWin95Scale()
  return <div className="win95-report-header" style={{ left: -scrollX, width: widths.name + widths.type + widths.location }}>
    {([['name', '&Name'], ['type', '&Type'], ['location', '&Location']] as const).map(([column, label]) => <button type="button" key={column} style={{ width: widths[column] }}>
      <Win95BitmapText text={label} />
      <span className="win95-report-resizer"
        onPointerDown={(event) => { event.preventDefault(); event.stopPropagation(); drag.current = { column, x: event.clientX }; event.currentTarget.setPointerCapture(event.pointerId) }}
        onPointerMove={(event) => { if (!drag.current) return; const delta = toLogicalDelta(event.clientX - drag.current.x); drag.current.x = event.clientX; onResize(drag.current.column, delta) }}
        onPointerUp={(event) => { drag.current = null; if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId) }} />
    </button>)}
  </div>
}
