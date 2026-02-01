import React, { useState, useCallback } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { getIconSrc, BUILTIN_ICONS } from '@/utils/icons'

export const GroupPropertiesDialog: React.FC = () => {
  const { dialogData, closeDialog, openDialog } = useUIStore()
  const { updateGroup, deleteGroup } = useProgramStore()
  const { closeWindow } = useMDIStore()

  const group = dialogData.group
  if (!group) return null

  const [name, setName] = useState(group.name)
  const [icon, setIcon] = useState(group.icon || 'folder')
  const [showIconPicker, setShowIconPicker] = useState(dialogData.showIconPicker ?? false)

  const handleSubmit = useCallback(
    (event: React.FormEvent) => {
      event.preventDefault()
      if (!name.trim()) return

      updateGroup(group.id, {
        name: name.trim(),
        icon
      })
      closeDialog()
    },
    [name, icon, group.id, updateGroup, closeDialog]
  )

  const handleDelete = useCallback(() => {
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
  }, [group.id, group.name, deleteGroup, closeWindow, openDialog])

  return (
    <Dialog title="Program Group Properties" onClose={closeDialog} width={400}>
      <form onSubmit={handleSubmit}>
        <div className="win31-form-row">
          <label htmlFor="group-name">Description:</label>
          <TextInput
            id="group-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
          />
        </div>

        <div className="win31-form-row">
          <label>Icon:</label>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1 }}>
            <img
              src={getIconSrc(icon)}
              alt="Icon"
              width={32}
              height={32}
              style={{ imageRendering: 'pixelated' }}
            />
            <Button type="button" onClick={() => setShowIconPicker(!showIconPicker)}>
              {showIconPicker ? 'Hide Icons' : 'Change Icon...'}
            </Button>
          </div>
        </div>

        {showIconPicker && (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(8, 1fr)',
              gap: 4,
              padding: 8,
              background: 'var(--win31-white)',
              border: '2px inset var(--bevel-dark)',
              marginBottom: 10,
              maxHeight: 150,
              overflowY: 'auto'
            }}
          >
            {BUILTIN_ICONS.map((iconOption) => (
              <div
                key={iconOption.id}
                onClick={() => setIcon(iconOption.id)}
                title={iconOption.name}
                style={{
                  width: 36,
                  height: 36,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  border: icon === iconOption.id ? '2px solid var(--win31-blue)' : '2px solid transparent',
                  background: icon === iconOption.id ? 'var(--selection-bg)' : 'transparent'
                }}
              >
                <img
                  src={iconOption.icon}
                  alt={iconOption.name}
                  width={32}
                  height={32}
                  style={{ imageRendering: 'pixelated' }}
                />
              </div>
            ))}
          </div>
        )}

        <div className="win31-dialog-buttons">
          <Button type="submit" isDefault disabled={!name.trim()}>
            OK
          </Button>
          <Button type="button" onClick={closeDialog}>
            Cancel
          </Button>
          <Button type="button" onClick={handleDelete}>
            Delete
          </Button>
        </div>
      </form>
    </Dialog>
  )
}
