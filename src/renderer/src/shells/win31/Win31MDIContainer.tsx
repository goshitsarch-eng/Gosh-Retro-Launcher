import { useEffect, useMemo, useRef, useState, type JSX } from 'react'
import { getGroupWindowState, type ProgramGroup } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { useUIStore } from '@/store/uiStore'
import { useWin31Scale } from './Win31ScaleContext'
import { WFW_METRICS } from './tokens'
import { getWfwIconSrc } from './iconCatalog'
import { Win31MDIWindow } from './Win31MDIWindow'

export function Win31MDIContainer(): JSX.Element {
  const rootRef = useRef<HTMLDivElement>(null)
  const groups = useProgramStore((state) => state.groups)
  const updateState = useProgramStore((state) => state.updateGroupWindowState)
  const updateIconPosition = useProgramStore((state) => state.updateGroupIconPosition)
  const windows = useMDIStore((state) => state.windows)
  const activeWindowId = useMDIStore((state) => state.activeWindowId)
  const openWindow = useMDIStore((state) => state.openWindow)
  const closeWindow = useMDIStore((state) => state.closeWindow)
  const focusWindow = useMDIStore((state) => state.focusWindow)
  const setActiveWindow = useMDIStore((state) => state.setActiveWindow)
  const selection = useUIStore((state) => state.win31Selection)
  const setSelection = useUIStore((state) => state.setWin31Selection)
  const setSelectedItem = useUIStore((state) => state.setSelectedItem)
  const clearSelection = useUIStore((state) => state.clearSelection)
  const { scale, toLogicalDelta } = useWin31Scale()
  const [clientSize, setClientSize] = useState({ width: 634, height: 430 })

  useEffect(() => {
    const knownIds = new Set(useMDIStore.getState().windows.map((entry) => entry.groupId))
    const groupIds = new Set(groups.map((group) => group.id))
    groups.forEach((group) => {
      if (!knownIds.has(group.id)) openWindow(group.id)
    })
    knownIds.forEach((groupId) => {
      if (!groupIds.has(groupId)) closeWindow(groupId)
    })

    const currentActive = useMDIStore.getState().activeWindowId
    const activeIsVisible = groups.some((group) =>
      group.id === currentActive && !getGroupWindowState(group, 'win31').minimized)
    if (!activeIsVisible) {
      const nextActive = [...groups].reverse().find((group) => !getGroupWindowState(group, 'win31').minimized)
      setActiveWindow(nextActive?.id ?? null)
    }
  }, [closeWindow, groups, openWindow, setActiveWindow])

  useEffect(() => {
    const root = rootRef.current
    if (!root) return
    const measure = (): void => {
      const rect = root.getBoundingClientRect()
      setClientSize({ width: Math.max(1, rect.width / scale), height: Math.max(1, rect.height / scale) })
    }
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(root)
    return () => observer.disconnect()
  }, [scale])

  const minimizedGroups = useMemo(() => groups.filter((group) => getGroupWindowState(group, 'win31').minimized), [groups])
  const columns = Math.max(1, Math.floor(clientSize.width / WFW_METRICS.groupCellWidth))
  const iconRows = minimizedGroups.length > 0 ? Math.ceil(minimizedGroups.length / columns) : 0
  const reservedBottom = iconRows > 0 ? iconRows * WFW_METRICS.groupCellHeight + 8 : 0

  useEffect(() => {
    const cascade = (): void => {
      const restorable = groups.filter((group) => !getGroupWindowState(group, 'win31').minimized)
      if (restorable.length === 0) return
      const offset = 22
      const availableHeight = Math.max(92, clientSize.height - reservedBottom)
      const width = Math.max(150, clientSize.width - offset * Math.max(1, restorable.length - 1))
      const height = Math.max(92, availableHeight - offset * Math.max(1, restorable.length - 1))
      restorable.forEach((group, index) => updateState(group.id, {
        x: index * offset,
        y: index * offset,
        width,
        height,
        maximized: false
      }, 'win31'))
    }
    const tile = (): void => {
      const restorable = groups.filter((group) => !getGroupWindowState(group, 'win31').minimized)
      if (restorable.length === 0) return
      const availableHeight = Math.max(92, clientSize.height - reservedBottom)
      const tileColumns = Math.ceil(Math.sqrt(restorable.length))
      const rows = Math.ceil(restorable.length / tileColumns)
      const width = Math.floor(clientSize.width / tileColumns)
      const height = Math.floor(availableHeight / rows)
      restorable.forEach((group, index) => updateState(group.id, {
        x: (index % tileColumns) * width,
        y: Math.floor(index / tileColumns) * height,
        width,
        height,
        maximized: false
      }, 'win31'))
    }
    const arrangeIcons = (): void => {
      minimizedGroups.forEach((group, index) => {
        const rowFromBottom = Math.floor(index / columns)
        const column = index % columns
        updateIconPosition(group.id, {
          x: column * WFW_METRICS.groupCellWidth,
          y: Math.max(0, clientSize.height - (rowFromBottom + 1) * WFW_METRICS.groupCellHeight - 8)
        })
      })
    }
    window.addEventListener('mdi-cascade', cascade)
    window.addEventListener('mdi-tile', tile)
    window.addEventListener('mdi-arrange-icons', arrangeIcons)
    return () => {
      window.removeEventListener('mdi-cascade', cascade)
      window.removeEventListener('mdi-tile', tile)
      window.removeEventListener('mdi-arrange-icons', arrangeIcons)
    }
  }, [clientSize, columns, groups, minimizedGroups, reservedBottom, updateIconPosition, updateState])

  const zIndexOf = (groupId: string): number => windows.find((windowState) => windowState.groupId === groupId)?.zIndex ?? 1
  const restoreGroup = (group: ProgramGroup): void => {
    updateState(group.id, { minimized: false }, 'win31')
    focusWindow(group.id)
    clearSelection()
  }

  return (
    <div
      ref={rootRef}
      className="wfw-mdi-client"
      onPointerDown={(event) => {
        if (event.target === rootRef.current) clearSelection()
      }}
    >
      {groups.map((group) => (
        <Win31MDIWindow
          key={group.id}
          group={group}
          active={activeWindowId === group.id}
          zIndex={zIndexOf(group.id)}
          clientSize={clientSize}
          onActivate={() => { focusWindow(group.id); clearSelection() }}
          onMaximize={() => {
            groups.forEach((other) => {
              if (other.id !== group.id && getGroupWindowState(other, 'win31').maximized) {
                updateState(other.id, { maximized: false }, 'win31')
              }
            })
            focusWindow(group.id)
          }}
        />
      ))}
      {minimizedGroups.map((group, index) => {
        const fallback = {
          x: (index % columns) * WFW_METRICS.groupCellWidth,
          y: Math.max(0, clientSize.height - (Math.floor(index / columns) + 1) * WFW_METRICS.groupCellHeight - 8)
        }
        const storedPosition = group.win31IconPosition ?? fallback
        const position = {
          x: Math.max(0, Math.min(clientSize.width - WFW_METRICS.groupCellWidth, storedPosition.x)),
          y: Math.max(0, Math.min(clientSize.height - WFW_METRICS.groupCellHeight, storedPosition.y))
        }
        const selected = selection?.kind === 'groupIcon' && selection.groupId === group.id
        return (
          <button
            key={`icon-${group.id}`}
            className={`wfw-minimized-group ${selected ? 'selected' : ''}`}
            style={{ left: position.x, top: position.y, zIndex: 10000 }}
            onPointerDown={(event) => {
              if (event.button !== 0) return
              event.stopPropagation()
              setSelection({ kind: 'groupIcon', groupId: group.id })
              setSelectedItem(null, null)
              const origin = position
              const startX = event.clientX, startY = event.clientY
              const element = event.currentTarget
              element.setPointerCapture(event.pointerId)
              const calculate = (pointerEvent: PointerEvent) => ({
                x: Math.round(Math.max(0, Math.min(clientSize.width - WFW_METRICS.groupCellWidth, origin.x + toLogicalDelta(pointerEvent.clientX - startX)))),
                y: Math.round(Math.max(0, Math.min(clientSize.height - WFW_METRICS.groupCellHeight, origin.y + toLogicalDelta(pointerEvent.clientY - startY))))
              })
              const move = (moveEvent: PointerEvent): void => {
                const next = calculate(moveEvent)
                element.style.left = `${next.x}px`
                element.style.top = `${next.y}px`
              }
              const end = (endEvent: PointerEvent): void => {
                element.removeEventListener('pointermove', move)
                element.removeEventListener('pointerup', end)
                updateIconPosition(group.id, calculate(endEvent))
              }
              element.addEventListener('pointermove', move)
              element.addEventListener('pointerup', end)
            }}
            onDoubleClick={() => restoreGroup(group)}
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                event.preventDefault()
                restoreGroup(group)
              }
            }}
          >
            <img src={getWfwIconSrc(group.icon || 'group', scale)} alt="" draggable={false} />
            <span>{group.name}</span>
          </button>
        )
      })}
    </div>
  )
}
