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
  const openDialog = useUIStore((state) => state.openDialog)

  // Handle double-click to launch
  const handleDoubleClick = useCallback(async () => {
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

  // Get icon path using helper that provides embedded fallbacks
  const iconSrc = getIconSrc(item.icon)

  return (
    <div
      className={`win31-program-item ${isSelected ? 'selected' : ''}`}
      onClick={onSelect}
      onDoubleClick={handleDoubleClick}
      onContextMenu={handleContextMenu}
    >
      <Icon src={iconSrc} alt={item.name} />
      <span className={`label label-${settings.labelDisplay || 'wrap'}`}>{item.name}</span>
    </div>
  )
}
