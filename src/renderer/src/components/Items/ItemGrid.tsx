import React, { useCallback, useState, useRef, useEffect, useMemo } from 'react'
import { ProgramItem } from './ProgramItem'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import type { ProgramItem as ProgramItemType } from '@shared/types'

interface ItemGridProps {
  groupId: string
  groupName: string
  items: ProgramItemType[]
}

export const ItemGrid: React.FC<ItemGridProps> = ({ groupId, groupName, items }) => {
  const [isDragOver, setIsDragOver] = useState(false)
  const [contextMenu, setContextMenu] = useState<{ x: number; y: number } | null>(null)
  const settings = useProgramStore((state) => state.settings)
  const { selectedItemId, selectedGroupId, setSelectedItem, clearSelection } = useUIStore()
  const openDialog = useUIStore((state) => state.openDialog)
  const addItem = useProgramStore((state) => state.addItem)
  const gridRef = useRef<HTMLDivElement>(null)
  const contextMenuRef = useRef<HTMLDivElement>(null)
  const displayedItems = useMemo(() => {
    if (!settings.autoArrange) return items
    return [...items].sort((a, b) =>
      a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: 'base' })
    )
  }, [items, settings.autoArrange])

  // Handle item selection
  const handleSelectItem = useCallback(
    (itemId: string) => {
      setSelectedItem(itemId, groupId)
    },
    [groupId, setSelectedItem]
  )

  // Handle click on empty area to deselect
  const handleBackgroundClick = useCallback(
    (event: React.MouseEvent) => {
      if (event.target === event.currentTarget) {
        clearSelection()
      }
      setContextMenu(null)
    },
    [clearSelection]
  )

  // Handle right-click on grid background
  const handleGridContextMenu = useCallback(
    (event: React.MouseEvent) => {
      if (event.target !== event.currentTarget) return
      event.preventDefault()
      clearSelection()
      setContextMenu({ x: event.clientX, y: event.clientY })
    },
    [clearSelection]
  )

  // Close context menu on outside click or escape
  useEffect(() => {
    if (!contextMenu) return
    const close = () => setContextMenu(null)
    const handleKey = (e: KeyboardEvent) => { if (e.key === 'Escape') close() }
    window.addEventListener('click', close)
    window.addEventListener('keydown', handleKey)
    return () => {
      window.removeEventListener('click', close)
      window.removeEventListener('keydown', handleKey)
    }
  }, [contextMenu])

  // Handle drag over
  const handleDragOver = useCallback((event: React.DragEvent) => {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
    setIsDragOver(true)
  }, [])

  // Handle drag leave
  const handleDragLeave = useCallback(() => {
    setIsDragOver(false)
  }, [])

  // Handle drop
  const handleDrop = useCallback(
    async (event: React.DragEvent) => {
      event.preventDefault()
      setIsDragOver(false)

      const files = event.dataTransfer.files
      if (files.length === 0) return

      for (const file of Array.from(files)) {
        // Get the file path (Electron-specific)
        const filePath = (file as any).path as string
        if (!filePath) continue

        try {
          // Get app info including icon from main process
          const appInfo = await window.electronAPI.app.getInfo(filePath)

          addItem(groupId, {
            name: appInfo.name,
            path: appInfo.path,
            icon: appInfo.icon || 'default',
            workingDir: appInfo.workingDir || '',
            launchGroup: 0
          })
        } catch (error) {
          console.error('Failed to get app info:', error)
          // Fallback to basic info
          const fileName = file.name
          const nameWithoutExt = fileName.replace(/\.[^/.]+$/, '')

          addItem(groupId, {
            name: nameWithoutExt,
            path: filePath,
            icon: 'default',
            workingDir: '',
            launchGroup: 0
          })
        }
      }
    },
    [groupId, addItem]
  )

  // Arrow key navigation
  const handleKeyDown = useCallback(
    (event: React.KeyboardEvent) => {
      if (displayedItems.length === 0) return
      if (!['ArrowRight', 'ArrowLeft', 'ArrowDown', 'ArrowUp'].includes(event.key)) return

      event.preventDefault()
      const grid = gridRef.current
      if (!grid) return

      const focusableItems = Array.from(
        grid.querySelectorAll<HTMLElement>('.win31-program-item')
      )
      const currentIndex = focusableItems.findIndex(
        (el) => el === document.activeElement
      )

      // Estimate columns from grid layout
      const gridWidth = grid.clientWidth
      const itemWidth = focusableItems[0]?.offsetWidth ?? 80
      const columns = Math.max(1, Math.floor(gridWidth / itemWidth))

      let nextIndex = currentIndex
      switch (event.key) {
        case 'ArrowRight':
          nextIndex = Math.min(currentIndex + 1, focusableItems.length - 1)
          break
        case 'ArrowLeft':
          nextIndex = Math.max(currentIndex - 1, 0)
          break
        case 'ArrowDown':
          nextIndex = Math.min(currentIndex + columns, focusableItems.length - 1)
          break
        case 'ArrowUp':
          nextIndex = Math.max(currentIndex - columns, 0)
          break
      }

      if (nextIndex !== currentIndex && focusableItems[nextIndex]) {
        focusableItems[nextIndex].focus()
      }
    },
    [displayedItems.length]
  )

  return (
    <div
      ref={gridRef}
      className={`win31-item-grid ${isDragOver ? 'drag-over' : ''}`}
      role="listbox"
      aria-label={`${groupName} programs`}
      onClick={handleBackgroundClick}
      onContextMenu={handleGridContextMenu}
      onKeyDown={handleKeyDown}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {displayedItems.map((item) => (
        <ProgramItem
          key={item.id}
          item={item}
          groupId={groupId}
          isSelected={selectedItemId === item.id && selectedGroupId === groupId}
          onSelect={() => handleSelectItem(item.id)}
        />
      ))}
      {displayedItems.length === 0 && (
        <div
          className="empty-message"
          style={{
            color: 'var(--text-disabled)',
            padding: '32px 20px',
            textAlign: 'center',
            width: '100%'
          }}
        >
          <div style={{ marginBottom: 4 }}>No program items</div>
          <div style={{ fontSize: '11px' }}>
            Drag files here or use File &rarr; New to add programs
          </div>
        </div>
      )}
      {contextMenu && (
        <div
          ref={contextMenuRef}
          className="win31-context-menu"
          style={{ left: contextMenu.x, top: contextMenu.y, position: 'fixed' }}
          onClick={(e) => e.stopPropagation()}
          onContextMenu={(e) => e.preventDefault()}
        >
          <div
            className="win31-menu-item"
            onClick={() => {
              openDialog('newItem', { groupId })
              setContextMenu(null)
            }}
          >
            New Item...
          </div>
          <div
            className="win31-menu-item"
            onClick={() => {
              openDialog('newUrl', { groupId })
              setContextMenu(null)
            }}
          >
            New URL...
          </div>
        </div>
      )}
    </div>
  )
}
