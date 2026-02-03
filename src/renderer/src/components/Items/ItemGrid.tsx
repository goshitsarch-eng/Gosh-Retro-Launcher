import React, { useCallback, useState } from 'react'
import { ProgramItem } from './ProgramItem'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import type { ProgramItem as ProgramItemType } from '@shared/types'

interface ItemGridProps {
  groupId: string
  items: ProgramItemType[]
}

export const ItemGrid: React.FC<ItemGridProps> = ({ groupId, items }) => {
  const [isDragOver, setIsDragOver] = useState(false)
  const { selectedItemId, selectedGroupId, setSelectedItem, clearSelection } = useUIStore()
  const addItem = useProgramStore((state) => state.addItem)

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
    },
    [clearSelection]
  )

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
    (event: React.DragEvent) => {
      event.preventDefault()
      setIsDragOver(false)

      const files = event.dataTransfer.files
      if (files.length === 0) return

      Array.from(files).forEach((file) => {
        // Get the file path (Electron-specific)
        const filePath = (file as any).path as string
        if (!filePath) return

        // Extract filename without extension for display name
        const fileName = file.name
        const nameWithoutExt = fileName.replace(/\.[^/.]+$/, '')

        addItem(groupId, {
          name: nameWithoutExt,
          path: filePath,
          icon: 'default-item.png',
          workingDir: '',
          shortcutKey: '',
          launchGroup: 0
        })
      })
    },
    [groupId, addItem]
  )

  return (
    <div
      className={`win31-item-grid ${isDragOver ? 'drag-over' : ''}`}
      onClick={handleBackgroundClick}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
    >
      {items.map((item) => (
        <ProgramItem
          key={item.id}
          item={item}
          groupId={groupId}
          isSelected={selectedItemId === item.id && selectedGroupId === groupId}
          onSelect={() => handleSelectItem(item.id)}
        />
      ))}
      {items.length === 0 && (
        <div className="empty-message" style={{ color: '#808080', padding: '20px' }}>
          Drag files here to add programs
        </div>
      )}
    </div>
  )
}
