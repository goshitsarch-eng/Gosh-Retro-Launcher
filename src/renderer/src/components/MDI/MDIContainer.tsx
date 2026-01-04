import React, { useRef, useEffect, useCallback, useState } from 'react'
import { MDIWindow } from './MDIWindow'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { useUIStore } from '@/store/uiStore'
import { getIconSrc } from '@/utils/icons'
import type { ProgramGroup } from '@shared/types'

export const MDIContainer: React.FC = () => {
  const containerRef = useRef<HTMLDivElement>(null)
  const contextMenuRef = useRef<HTMLDivElement>(null)
  const groups = useProgramStore((state) => state.groups)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const deleteGroup = useProgramStore((state) => state.deleteGroup)
  const { windows, activeWindowId, openWindow, focusWindow, closeWindow } = useMDIStore()
  const openDialog = useUIStore((state) => state.openDialog)
  const [contextMenu, setContextMenu] = useState<{
    x: number
    y: number
    group: ProgramGroup
  } | null>(null)

  // Open windows for all groups - runs when groups change
  useEffect(() => {
    groups.forEach((group) => {
      // Check if window already exists in MDI store
      const windowExists = windows.some((w) => w.groupId === group.id)
      if (!windowExists && !group.windowState.minimized) {
        openWindow(group.id)
      }
    })
  }, [groups, windows, openWindow])

  // Handle cascade windows event
  const handleCascade = useCallback(() => {
    groups.forEach((group, index) => {
      updateGroupWindowState(group.id, {
        x: 20 + index * 30,
        y: 20 + index * 30,
        width: 300,
        height: 200,
        minimized: false,
        maximized: false
      })
    })
  }, [groups, updateGroupWindowState])

  // Handle tile windows event
  const handleTile = useCallback(() => {
    if (!containerRef.current) return

    const visibleGroups = groups.filter((g) => !g.windowState.minimized)
    const count = visibleGroups.length
    if (count === 0) return

    const containerRect = containerRef.current.getBoundingClientRect()
    const cols = Math.ceil(Math.sqrt(count))
    const rows = Math.ceil(count / cols)
    const width = Math.floor(containerRect.width / cols)
    const height = Math.floor(containerRect.height / rows)

    visibleGroups.forEach((group, index) => {
      const col = index % cols
      const row = Math.floor(index / cols)
      updateGroupWindowState(group.id, {
        x: col * width,
        y: row * height,
        width,
        height,
        minimized: false,
        maximized: false
      })
    })
  }, [groups, updateGroupWindowState])

  // Handle arrange icons event
  const handleArrangeIcons = useCallback(() => {
    const minimizedGroups = groups.filter((g) => g.windowState.minimized)
    minimizedGroups.forEach((group, index) => {
      updateGroupWindowState(group.id, {
        x: 10 + (index % 8) * 75,
        y: 10 + Math.floor(index / 8) * 75
      })
    })
  }, [groups, updateGroupWindowState])

  // Listen for window arrangement events
  useEffect(() => {
    window.addEventListener('mdi-cascade', handleCascade)
    window.addEventListener('mdi-tile', handleTile)
    window.addEventListener('mdi-arrange-icons', handleArrangeIcons)

    return () => {
      window.removeEventListener('mdi-cascade', handleCascade)
      window.removeEventListener('mdi-tile', handleTile)
      window.removeEventListener('mdi-arrange-icons', handleArrangeIcons)
    }
  }, [handleCascade, handleTile, handleArrangeIcons])

  useEffect(() => {
    if (!contextMenu) return

    const handleClick = () => setContextMenu(null)
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setContextMenu(null)
      }
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

  useEffect(() => {
    if (!contextMenu || !contextMenuRef.current) return

    const menuRect = contextMenuRef.current.getBoundingClientRect()
    const padding = 4
    let x = contextMenu.x
    let y = contextMenu.y

    x = Math.max(padding, Math.min(x, window.innerWidth - menuRect.width - padding))
    y = Math.max(padding, Math.min(y, window.innerHeight - menuRect.height - padding))

    if (x !== contextMenu.x || y !== contextMenu.y) {
      setContextMenu((prev) => (prev ? { ...prev, x, y } : prev))
    }
  }, [contextMenu])

  // Get visible and minimized groups
  const visibleGroups = groups.filter((g) => !g.windowState.minimized)
  const minimizedGroups = groups.filter((g) => g.windowState.minimized)

  // Get z-index for a window
  const getZIndex = (groupId: string): number => {
    const window = windows.find((w) => w.groupId === groupId)
    return window?.zIndex ?? 0
  }

  const restoreGroup = useCallback(
    (group: ProgramGroup) => {
      updateGroupWindowState(group.id, { minimized: false })
      focusWindow(group.id)
    },
    [updateGroupWindowState, focusWindow]
  )

  const confirmDeleteGroup = useCallback(
    (group: ProgramGroup) => {
      openDialog('confirm', {
        confirmOptions: {
          title: 'Delete Group',
          message: `Are you sure you want to delete "${group.name}" and all its items?`,
          onConfirm: () => {
            closeWindow(group.id)
            deleteGroup(group.id)
          }
        }
      })
    },
    [openDialog, closeWindow, deleteGroup]
  )

  return (
    <div
      ref={containerRef}
      className="win31-mdi-container"
      onClick={() => {
        if (contextMenu) {
          setContextMenu(null)
        }
      }}
    >
      {/* Visible windows */}
      {visibleGroups.map((group) => (
        <MDIWindow
          key={group.id}
          group={group}
          isActive={activeWindowId === group.id}
          zIndex={getZIndex(group.id)}
          containerRef={containerRef}
          onFocus={() => focusWindow(group.id)}
        />
      ))}

      {/* Minimized icons at bottom */}
      {minimizedGroups.length > 0 && (
        <div className="win31-mdi-icon-bar">
          {minimizedGroups.map((group) => (
            <div
              key={group.id}
              className="win31-mdi-icon"
              onDoubleClick={() => restoreGroup(group)}
              onContextMenu={(event) => {
                event.preventDefault()
                event.stopPropagation()
                setContextMenu({
                  x: event.clientX,
                  y: event.clientY,
                  group
                })
              }}
            >
              <img
                src={getIconSrc(group.icon)}
                alt={group.name}
                className="icon"
                draggable={false}
              />
              <span className="label">{group.name}</span>
            </div>
          ))}
        </div>
      )}
      {contextMenu && (
        <div
          ref={contextMenuRef}
          className="win31-context-menu"
          style={{ left: contextMenu.x, top: contextMenu.y }}
          onClick={(event) => event.stopPropagation()}
          onContextMenu={(event) => event.preventDefault()}
        >
          <div
            className="win31-menu-item"
            onClick={() => {
              restoreGroup(contextMenu.group)
              setContextMenu(null)
            }}
          >
            Open
          </div>
          <div className="win31-menu-separator" />
          <div
            className="win31-menu-item"
            onClick={() => {
              openDialog('renameGroup', { group: contextMenu.group })
              setContextMenu(null)
            }}
          >
            Rename...
          </div>
          <div
            className="win31-menu-item"
            onClick={() => {
              openDialog('groupProperties', {
                group: contextMenu.group,
                showIconPicker: true
              })
              setContextMenu(null)
            }}
          >
            Change Icon...
          </div>
          <div
            className="win31-menu-item"
            onClick={() => {
              openDialog('groupProperties', { group: contextMenu.group })
              setContextMenu(null)
            }}
          >
            Properties...
          </div>
          <div className="win31-menu-separator" />
          <div
            className="win31-menu-item"
            onClick={() => {
              confirmDeleteGroup(contextMenu.group)
              setContextMenu(null)
            }}
          >
            Delete
          </div>
        </div>
      )}
    </div>
  )
}
