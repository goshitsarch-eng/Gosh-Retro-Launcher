import React, { useCallback, useRef, useState, useEffect } from 'react'
import { MDIWindowControls } from './MDIWindowControls'
import { ItemGrid } from '../Items/ItemGrid'
import { useDraggable } from '@/hooks/useDraggable'
import { useResizable } from '@/hooks/useResizable'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { useUIStore } from '@/store/uiStore'
import { useSounds } from '@/hooks/useSounds'
import type { ProgramGroup } from '@shared/types'

interface MDIWindowProps {
  group: ProgramGroup
  isActive: boolean
  zIndex: number
  containerRef: React.RefObject<HTMLDivElement | null>
  onFocus: () => void
}

export const MDIWindow: React.FC<MDIWindowProps> = ({
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

  useEffect(() => {
    sounds.windowOpen()
  }, [])

  const { windowState } = group

  // Handle drag end
  const handleDragEnd = useCallback(
    (position: { x: number; y: number }) => {
      updateGroupWindowState(group.id, { x: position.x, y: position.y })
    },
    [group.id, updateGroupWindowState]
  )

  // Handle resize end
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
    handlePointerDown: handleDragPointerDown
  } = useDraggable({
    initialPosition: { x: windowState.x, y: windowState.y },
    containerRef,
    elementRef: windowRef,
    onDragStart: onFocus,
    onDragEnd: handleDragEnd
  })

  const {
    size: resizeSize,
    position: resizePosition,
    handleResizePointerDown
  } = useResizable({
    initialSize: { width: windowState.width, height: windowState.height },
    initialPosition: { x: windowState.x, y: windowState.y },
    minSize: { width: 150, height: 100 },
    elementRef: windowRef,
    onResizeStart: onFocus,
    onResizeEnd: handleResizeEnd
  })

  // Window actions
  const handleMinimize = useCallback(() => {
    sounds.windowClose()
    setAnimClass('anim-window-close')
    setTimeout(() => {
      updateGroupWindowState(group.id, { minimized: true })
      closeWindow(group.id)
    }, 120)
  }, [group.id, updateGroupWindowState, closeWindow, sounds])

  const handleMaximize = useCallback(() => {
    updateGroupWindowState(group.id, {
      maximized: !windowState.maximized
    })
  }, [group.id, windowState.maximized, updateGroupWindowState])

  const handleClose = useCallback(() => {
    sounds.windowClose()
    setAnimClass('anim-window-close')
    setTimeout(() => {
      updateGroupWindowState(group.id, { minimized: true })
      closeWindow(group.id)
    }, 120)
  }, [group.id, updateGroupWindowState, closeWindow, sounds])

  // Handle right-click on titlebar to open group properties
  const handleTitleBarContextMenu = useCallback(
    (event: React.MouseEvent) => {
      event.preventDefault()
      openDialog('groupProperties', { group })
    },
    [group, openDialog]
  )

  // Use resizePosition if resizing, otherwise dragPosition
  const x = resizePosition.x || dragPosition.x
  const y = resizePosition.y || dragPosition.y
  const width = windowState.maximized ? '100%' : resizeSize.width
  const height = windowState.maximized ? '100%' : resizeSize.height

  return (
    <div
      ref={windowRef}
      className={`win31-mdi-window ${isActive ? 'active' : 'inactive'} ${windowState.maximized ? 'maximized' : ''} ${animClass}`}
      style={{
        left: windowState.maximized ? 0 : x,
        top: windowState.maximized ? 0 : y,
        width,
        height,
        zIndex
      }}
      onMouseDown={onFocus}
    >
      {/* Title bar */}
      <div
        className="win31-titlebar"
        onPointerDown={windowState.maximized ? undefined : handleDragPointerDown}
        onContextMenu={handleTitleBarContextMenu}
      >
        <span className="win31-titlebar-text">{group.name}</span>
        <MDIWindowControls
          onMinimize={handleMinimize}
          onMaximize={handleMaximize}
          onClose={handleClose}
          isMaximized={windowState.maximized}
        />
      </div>

      {/* Content area */}
      <div className="win31-window-body">
        <ItemGrid groupId={group.id} groupName={group.name} items={group.items} />
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
            className="resize-handle resize-handle-se"
            onPointerDown={(e) => handleResizePointerDown(e, 'se')}
          />
        </>
      )}
    </div>
  )
}
