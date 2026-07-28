import React, { useState, useCallback } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { getIconSrc, BUILTIN_ICONS } from '@/utils/icons'

export const GroupPropertiesDialog: React.FC = () => {
  const dialogData = useUIStore((state) => state.dialogData)
  const closeDialog = useUIStore((state) => state.closeDialog)
  const openDialog = useUIStore((state) => state.openDialog)
  const updateGroup = useProgramStore((state) => state.updateGroup)
  const deleteGroup = useProgramStore((state) => state.deleteGroup)
  const closeWindow = useMDIStore((state) => state.closeWindow)

  const group = dialogData.group
  if (!group) return null

  const [name, setName] = useState(group.name)
  const [icon, setIcon] = useState(group.icon || 'folder')
  const [showIconPicker, setShowIconPicker] = useState(dialogData.showIconPicker ?? false)

  const handleSubmit = useCallback(
    (event: React.FormEvent) => {
      event.preventDefault()
      if (!name.trim()) return
      updateGroup(group.id, { name: name.trim(), icon })
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
    <Dialog title="Program Group Properties" onClose={closeDialog} width={390}>
      <form onSubmit={handleSubmit} className="win31-properties-layout">
        <div className="win31-properties-fields">
          <div className="win31-form-row">
            <label htmlFor="group-name"><span className="hotkey">D</span>escription:</label>
            <TextInput
              id="group-name"
              value={name}
              onChange={(event) => setName(event.target.value)}
              autoFocus
            />
          </div>
          <div className="win31-form-row win31-icon-preview-row">
            <label>Icon:</label>
            <div className="win31-icon-preview-well">
              <img src={getIconSrc(icon)} alt="Selected icon" width={32} height={32} />
            </div>
          </div>
          {showIconPicker && (
            <div className="win31-icon-picker" role="listbox" aria-label="Group icons">
              {BUILTIN_ICONS.map((iconOption) => (
                <button
                  type="button"
                  key={iconOption.id}
                  className={`win31-icon-choice ${icon === iconOption.id ? 'selected' : ''}`}
                  onClick={() => setIcon(iconOption.id)}
                  title={iconOption.name}
                  aria-label={iconOption.name}
                  aria-selected={icon === iconOption.id}
                  role="option"
                >
                  <img src={iconOption.icon} alt="" width={32} height={32} />
                </button>
              ))}
            </div>
          )}
        </div>
        <div className="win31-properties-buttons">
          <Button type="submit" isDefault disabled={!name.trim()}>OK</Button>
          <Button type="button" onClick={closeDialog}>Cancel</Button>
          <Button type="button" onClick={() => setShowIconPicker((shown) => !shown)}>
            {showIconPicker ? 'Hide Icons' : 'Change Icon...'}
          </Button>
          <Button type="button" onClick={handleDelete}>Delete</Button>
        </div>
      </form>
    </Dialog>
  )
}
