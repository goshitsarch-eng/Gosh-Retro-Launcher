import React, { useState, useCallback } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'

export const NewGroupDialog: React.FC = () => {
  const [name, setName] = useState('')
  const { dialogData, closeDialog, openDialog } = useUIStore()
  const { addGroup, updateGroupWindowState, settings } = useProgramStore()
  const openWindow = useMDIStore((state) => state.openWindow)
  const openItemAfterCreate = dialogData.openItemAfterCreate
  const openUrlAfterCreate = dialogData.openUrlAfterCreate

  const handleSubmit = useCallback(
    (event: React.FormEvent) => {
      event.preventDefault()
      if (name.trim()) {
        const newGroupId = addGroup(name.trim())
        if (settings.shell === 'win95') {
          updateGroupWindowState(newGroupId, { minimized: false })
          openWindow(newGroupId)
        }
        if (openItemAfterCreate) {
          openDialog('newItem', { groupId: newGroupId })
        } else if (openUrlAfterCreate) {
          openDialog('newUrl', { groupId: newGroupId })
        } else {
          closeDialog()
        }
      }
    },
    [
      name,
      addGroup,
      settings.shell,
      updateGroupWindowState,
      openWindow,
      openItemAfterCreate,
      openUrlAfterCreate,
      openDialog,
      closeDialog
    ]
  )

  return (
    <Dialog title="New Program Group" onClose={closeDialog} width={350}>
      <form onSubmit={handleSubmit}>
        {openItemAfterCreate && (
          <div style={{ marginBottom: 8, fontSize: 12 }}>
            Create a group to add your new program item.
          </div>
        )}
        {openUrlAfterCreate && (
          <div style={{ marginBottom: 8, fontSize: 12 }}>
            Create a group to add your URL.
          </div>
        )}
        <div className="win31-form-row">
          <label htmlFor="group-name">Description:</label>
          <TextInput
            id="group-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            placeholder="Enter group name"
          />
        </div>
        <div className="win31-dialog-buttons">
          <Button type="submit" isDefault disabled={!name.trim()}>
            OK
          </Button>
          <Button type="button" onClick={closeDialog}>
            Cancel
          </Button>
        </div>
      </form>
    </Dialog>
  )
}
