import React, { useRef, useEffect, useState } from 'react'
import { Win95Window } from './Win95Window'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { useUIStore } from '@/store/uiStore'

export const Win95Desktop: React.FC = () => {
  const containerRef = useRef<HTMLDivElement>(null)
  const contextMenuRef = useRef<HTMLDivElement>(null)
  const groups = useProgramStore((state) => state.groups)
  const windows = useMDIStore((state) => state.windows)
  const activeWindowId = useMDIStore((state) => state.activeWindowId)
  const focusWindow = useMDIStore((state) => state.focusWindow)
  const openDialog = useUIStore((state) => state.openDialog)
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number } | null>(null)

  // NO auto-open effect — Win95 desktop starts clean.
  // Windows are opened explicitly from the Start Menu or taskbar.

  // Close context menu on outside click or escape
  useEffect(() => {
    if (!contextMenu) return
    const handleClick = () => setContextMenu(null)
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setContextMenu(null)
    }
    window.addEventListener('click', handleClick)
    window.addEventListener('contextmenu', handleClick)
    window.addEventListener('keydown', handleKeyDown)
    return () => {
      window.removeEventListener('click', handleClick)
      window.removeEventListener('contextmenu', handleClick)
      window.removeEventListener('keydown', handleKeyDown)
    }
  }, [contextMenu])

  // Reposition context menu to stay in viewport
  const hasRepositioned = useRef(false)
  useEffect(() => {
    if (!contextMenu || !contextMenuRef.current) {
      hasRepositioned.current = false
      return
    }
    if (hasRepositioned.current) return
    const menuRect = contextMenuRef.current.getBoundingClientRect()
    const padding = 4
    let x = contextMenu.x
    let y = contextMenu.y
    x = Math.max(padding, Math.min(x, window.innerWidth - menuRect.width - padding))
    y = Math.max(padding, Math.min(y, window.innerHeight - menuRect.height - padding))
    if (x !== contextMenu.x || y !== contextMenu.y) {
      hasRepositioned.current = true
      setContextMenu({ x, y })
    }
  }, [contextMenu])

  // Only show windows that exist in mdiStore AND whose group is not minimized
  const openGroupIds = new Set(windows.map((w) => w.groupId))
  const visibleGroups = groups.filter(
    (g) => openGroupIds.has(g.id) && !g.windowState.minimized
  )

  const getZIndex = (groupId: string): number => {
    const win = windows.find((w) => w.groupId === groupId)
    return win?.zIndex ?? 0
  }

  return (
    <div
      ref={containerRef}
      className="win95-desktop"
      onContextMenu={(event) => {
        // Only show context menu when clicking the desktop background itself
        if (event.target === containerRef.current) {
          event.preventDefault()
          setContextMenu({ x: event.clientX, y: event.clientY })
        }
      }}
    >
      {visibleGroups.map((group) => (
        <Win95Window
          key={group.id}
          group={group}
          isActive={activeWindowId === group.id}
          zIndex={getZIndex(group.id)}
          containerRef={containerRef}
          onFocus={() => focusWindow(group.id)}
        />
      ))}

      {contextMenu && (
        <div
          ref={contextMenuRef}
          className="win95-context-menu"
          style={{ left: contextMenu.x, top: contextMenu.y }}
          onClick={(event) => event.stopPropagation()}
          onContextMenu={(event) => event.preventDefault()}
        >
          <div
            className="win95-menu-item"
            onClick={() => {
              openDialog('newGroup')
              setContextMenu(null)
            }}
          >
            New Group...
          </div>
          <div className="win95-menu-separator" />
          <div
            className="win95-menu-item"
            onClick={() => {
              openDialog('settings')
              setContextMenu(null)
            }}
          >
            Settings...
          </div>
        </div>
      )}
    </div>
  )
}
