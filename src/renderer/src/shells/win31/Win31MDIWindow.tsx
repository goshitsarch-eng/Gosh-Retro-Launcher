import { useEffect, useMemo, useRef, useState, type JSX, type RefObject } from 'react'
import { getGroupWindowState, type ProgramGroup } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { useWin31Scale } from './Win31ScaleContext'
import { Win31ItemGrid } from './Win31ItemGrid'
import { Win31PopupMenu, type Win31MenuItemModel } from './Win31MenuBar'
import type { Win31Command } from './commands'

interface Props {
  group: ProgramGroup
  active: boolean
  zIndex: number
  clientSize: { width: number; height: number }
  onActivate: () => void
  onMaximize: () => void
}

export function Win31MDIWindow({ group, active, zIndex, clientSize, onActivate, onMaximize }: Props): JSX.Element | null {
  const state = getGroupWindowState(group, 'win31')
  const updateState = useProgramStore((store) => store.updateGroupWindowState)
  const setSelection = useUIStore((store) => store.setWin31Selection)
  const { toLogicalDelta } = useWin31Scale()
  const [systemMenu, setSystemMenu] = useState(false)
  const [keyboardMode, setKeyboardMode] = useState<'move' | 'size' | null>(null)
  const rootRef = useRef<HTMLDivElement>(null)

  const restore = (): void => {
    updateState(group.id, {
      minimized: false,
      maximized: false,
      ...(state.restoreX !== undefined ? { x: state.restoreX } : {}),
      ...(state.restoreY !== undefined ? { y: state.restoreY } : {}),
      ...(state.restoreWidth !== undefined ? { width: state.restoreWidth } : {}),
      ...(state.restoreHeight !== undefined ? { height: state.restoreHeight } : {})
    }, 'win31')
    onActivate()
  }

  const maximize = (): void => {
    if (state.maximized) {
      restore()
      return
    }
    updateState(group.id, {
      maximized: true,
      minimized: false,
      restoreX: state.x,
      restoreY: state.y,
      restoreWidth: state.width,
      restoreHeight: state.height
    }, 'win31')
    onMaximize()
  }

  const minimize = (): void => {
    updateState(group.id, { minimized: true, maximized: false }, 'win31')
    setSelection({ kind: 'groupIcon', groupId: group.id })
  }

  useEffect(() => {
    const openMenu = (): void => { if (active) setSystemMenu(true) }
    window.addEventListener('wfw-child-system-menu', openMenu)
    return () => window.removeEventListener('wfw-child-system-menu', openMenu)
  }, [active])

  useEffect(() => {
    if (!keyboardMode) return
    const initial = { ...state }
    const keyDown = (event: KeyboardEvent): void => {
      if (event.key === 'Escape') {
        event.preventDefault()
        updateState(group.id, initial, 'win31')
        setKeyboardMode(null)
        return
      }
      if (event.key === 'Enter') {
        event.preventDefault()
        setKeyboardMode(null)
        return
      }
      const step = event.shiftKey ? 8 : 1
      let dx = 0, dy = 0
      if (event.key === 'ArrowLeft') dx = -step
      else if (event.key === 'ArrowRight') dx = step
      else if (event.key === 'ArrowUp') dy = -step
      else if (event.key === 'ArrowDown') dy = step
      else return
      event.preventDefault()
      const current = getGroupWindowState(
        useProgramStore.getState().groups.find((entry) => entry.id === group.id) ?? group,
        'win31'
      )
      if (keyboardMode === 'move') {
        updateState(group.id, {
          x: Math.max(0, Math.min(clientSize.width - current.width, current.x + dx)),
          y: Math.max(0, Math.min(clientSize.height - 24, current.y + dy))
        }, 'win31')
      } else {
        updateState(group.id, {
          width: Math.max(150, Math.min(clientSize.width - current.x, current.width + dx)),
          height: Math.max(92, Math.min(clientSize.height - current.y, current.height + dy))
        }, 'win31')
      }
    }
    window.addEventListener('keydown', keyDown)
    return () => window.removeEventListener('keydown', keyDown)
  }, [clientSize, group, keyboardMode, state, updateState])

  const menuItems = useMemo<Win31MenuItemModel[]>(() => [
    { command: 'child-restore', label: '&Restore', disabled: !state.maximized },
    { command: 'child-move', label: '&Move', disabled: state.maximized },
    { command: 'child-size', label: '&Size', disabled: state.maximized },
    { command: 'child-minimize', label: 'Mi&nimize' },
    { command: 'child-maximize', label: 'Ma&ximize', disabled: state.maximized },
    { separator: true },
    { command: 'child-close', label: '&Close' }
  ], [state.maximized])

  const systemCommand = (command: Win31Command): void => {
    setSystemMenu(false)
    if (command === 'child-restore') restore()
    else if (command === 'child-move') setKeyboardMode('move')
    else if (command === 'child-size') setKeyboardMode('size')
    else if (command === 'child-minimize' || command === 'child-close') minimize()
    else if (command === 'child-maximize') maximize()
  }

  if (state.minimized) return null
  const position = state.maximized
    ? { x: 0, y: 0, width: clientSize.width, height: clientSize.height }
    : {
        x: Math.max(0, Math.min(state.x, clientSize.width - 40)),
        y: Math.max(0, Math.min(state.y, clientSize.height - 24)),
        width: Math.min(state.width, clientSize.width),
        height: Math.min(state.height, clientSize.height)
      }

  const beginDrag = (event: React.PointerEvent): void => {
    if (event.button !== 0 || state.maximized || (event.target as HTMLElement).closest('button')) return
    onActivate()
    const start = { x: event.clientX, y: event.clientY, left: state.x, top: state.y }
    const element = event.currentTarget as HTMLElement
    element.setPointerCapture(event.pointerId)
    const move = (moveEvent: PointerEvent): void => {
      const x = Math.max(0, Math.min(clientSize.width - state.width, start.left + toLogicalDelta(moveEvent.clientX - start.x)))
      const y = Math.max(0, Math.min(clientSize.height - 24, start.top + toLogicalDelta(moveEvent.clientY - start.y)))
      if (rootRef.current) {
        rootRef.current.style.left = `${Math.round(x)}px`
        rootRef.current.style.top = `${Math.round(y)}px`
      }
    }
    const end = (endEvent: PointerEvent): void => {
      element.removeEventListener('pointermove', move)
      element.removeEventListener('pointerup', end)
      const x = Math.max(0, Math.min(clientSize.width - state.width, start.left + toLogicalDelta(endEvent.clientX - start.x)))
      const y = Math.max(0, Math.min(clientSize.height - 24, start.top + toLogicalDelta(endEvent.clientY - start.y)))
      updateState(group.id, { x: Math.round(x), y: Math.round(y) }, 'win31')
    }
    element.addEventListener('pointermove', move)
    element.addEventListener('pointerup', end)
  }

  return (
    <div
      ref={rootRef}
      className={`wfw-child-window ${active ? 'active' : 'inactive'} ${state.maximized ? 'maximized' : ''} ${keyboardMode ? 'keyboard-operation' : ''}`}
      style={{ left: position.x, top: position.y, width: position.width, height: position.height, zIndex }}
      onPointerDown={onActivate}
    >
      <div className="wfw-child-caption" onPointerDown={beginDrag} onDoubleClick={maximize}>
        <button className="wfw-system-button child" aria-label={`${group.name} system menu`} onPointerDown={(event) => event.stopPropagation()} onClick={() => setSystemMenu((open) => !open)}>
          <span />
        </button>
        <strong>{group.name}</strong>
        <div className="wfw-child-caption-controls">
          <button aria-label="Minimize" onClick={minimize}><span className="wfw-glyph-down" /></button>
          <button aria-label={state.maximized ? 'Restore' : 'Maximize'} onClick={maximize}><span className={state.maximized ? 'wfw-glyph-restore' : 'wfw-glyph-up'} /></button>
        </div>
        {systemMenu && <Win31PopupMenu className="wfw-system-popup child" items={menuItems} onCommand={systemCommand} onDismiss={() => setSystemMenu(false)} />}
      </div>
      <div className="wfw-child-content">
        <Win31ItemGrid group={group} />
      </div>
      {!state.maximized && <ResizeHandles group={group} clientSize={clientSize} rootRef={rootRef} />}
    </div>
  )
}

function ResizeHandles({ group, clientSize, rootRef }: {
  group: ProgramGroup
  clientSize: { width: number; height: number }
  rootRef: RefObject<HTMLDivElement | null>
}): JSX.Element {
  const updateState = useProgramStore((store) => store.updateGroupWindowState)
  const { toLogicalDelta } = useWin31Scale()
  const directions = ['n', 'e', 's', 'w', 'ne', 'nw', 'se', 'sw'] as const
  return <>{directions.map((direction) => (
    <div
      key={direction}
      className={`wfw-resize-handle ${direction}`}
      onPointerDown={(event) => {
        event.preventDefault()
        event.stopPropagation()
        const state = getGroupWindowState(group, 'win31')
        const startX = event.clientX, startY = event.clientY
        const element = event.currentTarget
        element.setPointerCapture(event.pointerId)
        const calculate = (pointerEvent: PointerEvent) => {
          const dx = toLogicalDelta(pointerEvent.clientX - startX)
          const dy = toLogicalDelta(pointerEvent.clientY - startY)
          let { x, y, width, height } = state
          if (direction.includes('e')) width = Math.max(150, Math.min(clientSize.width - x, state.width + dx))
          if (direction.includes('s')) height = Math.max(92, Math.min(clientSize.height - y, state.height + dy))
          if (direction.includes('w')) {
            x = Math.max(0, Math.min(state.x + state.width - 150, state.x + dx))
            width = state.width + (state.x - x)
          }
          if (direction.includes('n')) {
            y = Math.max(0, Math.min(state.y + state.height - 92, state.y + dy))
            height = state.height + (state.y - y)
          }
          return { x: Math.round(x), y: Math.round(y), width: Math.round(width), height: Math.round(height) }
        }
        const move = (moveEvent: PointerEvent): void => {
          const next = calculate(moveEvent)
          if (rootRef.current) Object.assign(rootRef.current.style, {
            left: `${next.x}px`, top: `${next.y}px`, width: `${next.width}px`, height: `${next.height}px`
          })
        }
        const end = (endEvent: PointerEvent): void => {
          element.removeEventListener('pointermove', move)
          element.removeEventListener('pointerup', end)
          updateState(group.id, calculate(endEvent), 'win31')
        }
        element.addEventListener('pointermove', move)
        element.addEventListener('pointerup', end)
      }}
    />
  ))}</>
}
