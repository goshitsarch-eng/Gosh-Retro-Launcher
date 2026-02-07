import React, { useCallback } from 'react'
import { Icon } from '../Common/Icon'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { getIconSrc } from '@/utils/icons'
import type { ProgramItem as ProgramItemType } from '@shared/types'

interface ProgramItemProps {
  item: ProgramItemType
  groupId: string
  isSelected: boolean
  onSelect: () => void
}

export const ProgramItem: React.FC<ProgramItemProps> = ({
  item,
  groupId,
  isSelected,
  onSelect
}) => {
  const settings = useProgramStore((state) => state.settings)
  const deleteItem = useProgramStore((state) => state.deleteItem)
  const openDialog = useUIStore((state) => state.openDialog)

  // Handle double-click to launch
  const handleLaunch = useCallback(async () => {
    try {
      const result = await window.electronAPI.program.launch(item)
      if (!result.success) {
        console.error('Failed to launch program:', result.error)
      }

      // Minimize main window if setting is enabled
      if (settings.minimizeOnUse) {
        window.electronAPI.window.minimize()
      }
    } catch (error) {
      console.error('Failed to launch program:', error)
    }
  }, [item, settings.minimizeOnUse])

  // Handle right-click context menu (properties)
  const handleContextMenu = useCallback(
    (event: React.MouseEvent) => {
      event.preventDefault()
      onSelect()
      openDialog('itemProperties', { groupId, item })
    },
    [groupId, item, onSelect, openDialog]
  )

  // Handle keyboard interaction
  const handleKeyDown = useCallback(
    (event: React.KeyboardEvent) => {
      if (event.key === 'Enter') {
        event.preventDefault()
        handleLaunch()
      } else if (event.key === 'Delete') {
        event.preventDefault()
        openDialog('confirm', {
          confirmOptions: {
            title: 'Delete Program Item',
            message: `Are you sure you want to delete "${item.name}"?`,
            onConfirm: () => deleteItem(groupId, item.id)
          }
        })
      }
    },
    [handleLaunch, openDialog, deleteItem, groupId, item]
  )

  // Select on focus (keyboard navigation)
  const handleFocus = useCallback(() => {
    onSelect()
  }, [onSelect])

  // Get icon path using helper that provides embedded fallbacks
  const iconSrc = getIconSrc(item.icon)

  return (
    <div
      className={`win31-program-item ${isSelected ? 'selected' : ''}`}
      tabIndex={0}
      role="option"
      aria-selected={isSelected}
      aria-label={item.name}
      onClick={onSelect}
      onDoubleClick={handleLaunch}
      onContextMenu={handleContextMenu}
      onKeyDown={handleKeyDown}
      onFocus={handleFocus}
    >
      <Icon src={iconSrc} alt={item.name} />
      <span className={`label label-${settings.labelDisplay || 'wrap'}`}>{item.name}</span>
    </div>
  )
}
