import { useCallback, useEffect, useMemo, useRef, useState, type JSX } from 'react'
import type { ProgramGroup, ProgramItem } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { useWin31Scale } from './Win31ScaleContext'
import { getWfwIconSrc, isExternalIcon } from './iconCatalog'
import { WFW_METRICS } from './tokens'

export function Win31ItemGrid({ group }: { group: ProgramGroup }): JSX.Element {
  const rootRef = useRef<HTMLDivElement>(null)
  const [logicalSize, setLogicalSize] = useState({ width: 300, height: 160 })
  const settings = useProgramStore((state) => state.settings)
  const updateItemPosition = useProgramStore((state) => state.updateItemPosition)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const selection = useUIStore((state) => state.win31Selection)
  const setSelection = useUIStore((state) => state.setWin31Selection)
  const setSelectedItem = useUIStore((state) => state.setSelectedItem)
  const clearSelection = useUIStore((state) => state.clearSelection)
  const openDialog = useUIStore((state) => state.openDialog)
  const { scale, toLogicalDelta } = useWin31Scale()

  useEffect(() => {
    const root = rootRef.current
    if (!root) return
    const update = (): void => {
      const bounds = root.getBoundingClientRect()
      setLogicalSize({ width: bounds.width / scale, height: bounds.height / scale })
    }
    update()
    const observer = new ResizeObserver(update)
    observer.observe(root)
    return () => observer.disconnect()
  }, [scale])

  const positions = useMemo(() => {
    const columns = Math.max(1, Math.floor((logicalSize.width - WFW_METRICS.programGridInsetX * 2) / WFW_METRICS.programCellWidth))
    return group.items.map((item, index) => settings.autoArrange || !item.win31Position
      ? {
          x: WFW_METRICS.programGridInsetX + (index % columns) * WFW_METRICS.programCellWidth,
          y: WFW_METRICS.programGridInsetY + Math.floor(index / columns) * WFW_METRICS.programCellHeight
        }
      : item.win31Position)
  }, [group.items, logicalSize.width, settings.autoArrange])

  const launch = useCallback(async (item: ProgramItem): Promise<void> => {
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
    if (settings.minimizeOnUse) updateGroupWindowState(group.id, { minimized: true }, 'win31')
  }, [group.id, openDialog, settings.minimizeOnUse, updateGroupWindowState])

  const selectByIndex = (index: number): void => {
    const item = group.items[index]
    if (!item) return
    setSelection({ kind: 'item', groupId: group.id, itemId: item.id })
    setSelectedItem(item.id, group.id)
    requestAnimationFrame(() => document.getElementById(`wfw-item-${item.id}`)?.focus())
  }

  return (
    <div
      ref={rootRef}
      className="wfw-item-area"
      role="listbox"
      tabIndex={0}
      aria-label={`${group.name} programs`}
      onPointerDown={(event) => {
        if (event.target === rootRef.current) clearSelection()
      }}
      onKeyDown={(event) => {
        if (group.items.length === 0) return
        const current = selection?.kind === 'item' && selection.groupId === group.id
          ? group.items.findIndex((item) => item.id === selection.itemId)
          : -1
        const columns = Math.max(1, Math.floor(
          (logicalSize.width - WFW_METRICS.programGridInsetX * 2) / WFW_METRICS.programCellWidth
        ))
        let next = current
        if (event.key === 'ArrowRight') next = Math.min(group.items.length - 1, Math.max(0, current + 1))
        else if (event.key === 'ArrowLeft') next = Math.max(0, current - 1)
        else if (event.key === 'ArrowDown') next = Math.min(group.items.length - 1, Math.max(0, current + columns))
        else if (event.key === 'ArrowUp') next = Math.max(0, current - columns)
        else if (event.key === 'Home') next = 0
        else if (event.key === 'End') next = group.items.length - 1
        else if (event.key === 'Enter' && current >= 0) {
          event.preventDefault()
          event.stopPropagation()
          void launch(group.items[current])
          return
        } else return
        event.preventDefault()
        selectByIndex(next)
      }}
    >
      {group.items.map((item, index) => {
        const selected = selection?.kind === 'item' && selection.groupId === group.id && selection.itemId === item.id
        const position = positions[index]
        return (
          <button
            id={`wfw-item-${item.id}`}
            key={item.id}
            role="option"
            aria-selected={selected}
            className={`wfw-program-item ${selected ? 'selected' : ''}`}
            style={{ left: position.x, top: position.y }}
            onPointerDown={(event) => {
              if (event.button !== 0) return
              event.stopPropagation()
              setSelection({ kind: 'item', groupId: group.id, itemId: item.id })
              setSelectedItem(item.id, group.id)
              if (settings.autoArrange) return
              const origin = position
              const pointerId = event.pointerId
              const startX = event.clientX
              const startY = event.clientY
              const element = event.currentTarget
              element.setPointerCapture(pointerId)
              const move = (moveEvent: PointerEvent): void => {
                const x = Math.max(0, Math.min(logicalSize.width - WFW_METRICS.programCellWidth, origin.x + toLogicalDelta(moveEvent.clientX - startX)))
                const y = Math.max(0, Math.min(logicalSize.height - WFW_METRICS.programCellHeight, origin.y + toLogicalDelta(moveEvent.clientY - startY)))
                element.style.left = `${Math.round(x)}px`
                element.style.top = `${Math.round(y)}px`
              }
              const end = (endEvent: PointerEvent): void => {
                element.removeEventListener('pointermove', move)
                element.removeEventListener('pointerup', end)
                element.removeEventListener('pointercancel', end)
                const x = Math.max(0, Math.min(logicalSize.width - WFW_METRICS.programCellWidth, origin.x + toLogicalDelta(endEvent.clientX - startX)))
                const y = Math.max(0, Math.min(logicalSize.height - WFW_METRICS.programCellHeight, origin.y + toLogicalDelta(endEvent.clientY - startY)))
                updateItemPosition(group.id, item.id, { x: Math.round(x), y: Math.round(y) })
              }
              element.addEventListener('pointermove', move)
              element.addEventListener('pointerup', end)
              element.addEventListener('pointercancel', end)
            }}
            onDoubleClick={() => void launch(item)}
          >
            <img
              className={!item.win31Icon && isExternalIcon(item.icon) ? 'external' : ''}
              src={getWfwIconSrc(item.win31Icon ?? item.icon, scale)}
              alt=""
              draggable={false}
            />
            <span>{item.name}</span>
          </button>
        )
      })}
    </div>
  )
}
