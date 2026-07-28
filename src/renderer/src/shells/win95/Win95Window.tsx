import React, { useCallback, useRef, useState, useEffect } from 'react'
import { ItemGrid } from '../../components/Items/ItemGrid'
import { useDraggable } from '@/hooks/useDraggable'
import { useResizable } from '@/hooks/useResizable'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { useUIStore } from '@/store/uiStore'
import { useSounds } from '@/hooks/useSounds'
import { getIconSrc } from '@/utils/icons'
import type { ProgramGroup } from '@shared/types'

interface Win95WindowProps {
  group: ProgramGroup
  isActive: boolean
  zIndex: number
  containerRef: React.RefObject<HTMLDivElement | null>
  onFocus: () => void
}

export const Win95Window: React.FC<Win95WindowProps> = ({
  group,
  isActive,
  zIndex,
  containerRef,
  onFocus
}) => {
  const windowRef = useRef<HTMLDivElement>(null)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const closeWindow = useMDIStore((state) => state.closeWindow)
  const openDialog = useUIStore((state) => state.openDialog)
  const sounds = useSounds()
  const [animClass, setAnimClass] = useState('anim-window-open')
  const actionTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    sounds.windowOpen()
    return () => {
      if (actionTimerRef.current !== null) {
        clearTimeout(actionTimerRef.current)
        actionTimerRef.current = null
      }
    }
  }, [sounds])

  const handleAnimationEnd = useCallback((event: React.AnimationEvent<HTMLDivElement>) => {
    if (event.currentTarget !== event.target) return
    setAnimClass((current) => (current === 'anim-window-open' ? '' : current))
  }, [])

  const handleDragStart = useCallback(() => {
    onFocus()
    setAnimClass((current) => (current === 'anim-window-open' ? '' : current))
  }, [onFocus])

  const { windowState } = group

  const handleDragEnd = useCallback(
    (position: { x: number; y: number }) => {
      updateGroupWindowState(group.id, { x: position.x, y: position.y })
    },
    [group.id, updateGroupWindowState]
  )

  const handleResizeEnd = useCallback(
    (size: { width: number; height: number }, position: { x: number; y: number }) => {
      updateGroupWindowState(group.id, {
        width: size.width,
        height: size.height,
        x: position.x,
        y: position.y
      })
    },
    [group.id, updateGroupWindowState]
  )

  const {
    position: dragPosition,
    isDragging,
    handlePointerDown: handleDragPointerDown
  } = useDraggable({
    initialPosition: { x: windowState.x, y: windowState.y },
    containerRef,
    elementRef: windowRef,
    onDragStart: handleDragStart,
    onDragEnd: handleDragEnd
  })

  const {
    size: resizeSize,
    position: resizePosition,
    isResizing,
    handleResizePointerDown
  } = useResizable({
    initialSize: { width: windowState.width, height: windowState.height },
    initialPosition: { x: windowState.x, y: windowState.y },
    minSize: { width: 150, height: 100 },
    elementRef: windowRef,
    onResizeStart: onFocus,
    onResizeEnd: handleResizeEnd
  })

  // Minimize: hide from desktop but keep in mdiStore (stays in taskbar)
  const handleMinimize = useCallback(() => {
    if (actionTimerRef.current !== null) clearTimeout(actionTimerRef.current)
    sounds.windowClose()
    setAnimClass('anim-window-minimize')
    actionTimerRef.current = setTimeout(() => {
      actionTimerRef.current = null
      updateGroupWindowState(group.id, { minimized: true })
    }, 200)
    // Do NOT call closeWindow — keep the mdiStore entry so taskbar still shows it
  }, [group.id, updateGroupWindowState, sounds])

  const handleMaximize = useCallback(() => {
    updateGroupWindowState(group.id, {
      maximized: !windowState.maximized
    })
  }, [group.id, windowState.maximized, updateGroupWindowState])

  // Close: remove from desktop AND taskbar entirely
  const handleClose = useCallback(() => {
    if (actionTimerRef.current !== null) clearTimeout(actionTimerRef.current)
    sounds.windowClose()
    setAnimClass('anim-window-close')
    actionTimerRef.current = setTimeout(() => {
      actionTimerRef.current = null
      updateGroupWindowState(group.id, { minimized: true })
      closeWindow(group.id)
    }, 120)
  }, [group.id, updateGroupWindowState, closeWindow, sounds])

  const handleTitleBarContextMenu = useCallback(
    (event: React.MouseEvent) => {
      event.preventDefault()
      openDialog('groupProperties', { group })
    },
    [group, openDialog]
  )

  const x = isResizing ? resizePosition.x : dragPosition.x
  const y = isResizing ? resizePosition.y : dragPosition.y
  const width = windowState.maximized ? '100%' : resizeSize.width
  const height = windowState.maximized ? '100%' : resizeSize.height

  return (
    <div
      ref={windowRef}
      className={`win95-window ${isActive ? 'active' : 'inactive'} ${windowState.maximized ? 'maximized' : ''} ${isDragging ? 'dragging' : ''} ${animClass}`}
      style={{
        left: windowState.maximized ? 0 : x,
        top: windowState.maximized ? 0 : y,
        width,
        height,
        zIndex
      }}
      onMouseDown={onFocus}
      onAnimationEnd={handleAnimationEnd}
    >
      {/* Title bar */}
      <div
        className="win95-window-titlebar"
        onPointerDown={windowState.maximized ? undefined : handleDragPointerDown}
        onContextMenu={handleTitleBarContextMenu}
      >
        <img
          src={getIconSrc(group.icon)}
          alt=""
          className="win95-window-titlebar-icon"
          draggable={false}
        />
        <span className="win95-window-titlebar-text">{group.name}</span>
        <div className="win95-window-titlebar-controls">
          <button
            className="win95-window-control-btn"
            onClick={(e) => {
              e.stopPropagation()
              handleMinimize()
            }}
            title="Minimize"
          >
            <span className="win95-glyph-minimize" />
          </button>
          <button
            className="win95-window-control-btn"
            onClick={(e) => {
              e.stopPropagation()
              handleMaximize()
            }}
            title={windowState.maximized ? 'Restore' : 'Maximize'}
          >
            <span className={windowState.maximized ? 'win95-glyph-restore' : 'win95-glyph-maximize'} />
          </button>
          <button
            className="win95-window-control-btn"
            onClick={(e) => {
              e.stopPropagation()
              handleClose()
            }}
            title="Close"
          >
            <span className="win95-glyph-close" />
          </button>
        </div>
      </div>

      <div className="win95-window-menubar">
        <span>File</span>
        <span>Edit</span>
        <span>View</span>
        <span>Help</span>
      </div>

      <div className="win95-window-toolbar">
        <button type="button" onClick={(e) => e.stopPropagation()}>Back</button>
        <button type="button" onClick={(e) => e.stopPropagation()}>Up</button>
        <span className="win95-window-address-label">Address</span>
        <div className="win95-window-address">{group.name}</div>
      </div>

      {/* Content area */}
      <div className="win95-window-body">
        <ItemGrid groupId={group.id} groupName={group.name} items={group.items} />
      </div>

      {/* Status bar */}
      <div className="win95-window-statusbar">
        {group.items.length} object{group.items.length !== 1 ? 's' : ''}
      </div>

      {/* Resize handles (only when not maximized) */}
      {!windowState.maximized && (
        <>
          <div
            className="resize-handle resize-handle-n"
            onPointerDown={(e) => handleResizePointerDown(e, 'n')}
          />
          <div
            className="resize-handle resize-handle-s"
            onPointerDown={(e) => handleResizePointerDown(e, 's')}
          />
          <div
            className="resize-handle resize-handle-w"
            onPointerDown={(e) => handleResizePointerDown(e, 'w')}
          />
          <div
            className="resize-handle resize-handle-e"
            onPointerDown={(e) => handleResizePointerDown(e, 'e')}
          />
          <div
            className="resize-handle resize-handle-nw"
            onPointerDown={(e) => handleResizePointerDown(e, 'nw')}
          />
          <div
            className="resize-handle resize-handle-ne"
            onPointerDown={(e) => handleResizePointerDown(e, 'ne')}
          />
          <div
            className="resize-handle resize-handle-sw"
            onPointerDown={(e) => handleResizePointerDown(e, 'sw')}
          />
          <div
            className="resize-handle resize-handle-se win95-resize-grip"
            onPointerDown={(e) => handleResizePointerDown(e, 'se')}
          />
        </>
      )}
    </div>
  )
}
