import React, { useState, useCallback, useEffect } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'

export const RenameGroupDialog: React.FC = () => {
  const { dialogData, closeDialog } = useUIStore()
  const updateGroup = useProgramStore((state) => state.updateGroup)
  const group = dialogData.group
  const [name, setName] = useState(group?.name || '')

  useEffect(() => {
    if (group) {
      setName(group.name)
    }
  }, [group])

  const handleSubmit = useCallback(
    (event: React.FormEvent) => {
      event.preventDefault()
      if (!group || !name.trim()) return
      updateGroup(group.id, { name: name.trim() })
      closeDialog()
    },
    [group, name, updateGroup, closeDialog]
  )

  if (!group) return null

  return (
    <Dialog title="Rename Program Group" onClose={closeDialog} width={350}>
      <form onSubmit={handleSubmit}>
        <div className="win31-form-row">
          <label htmlFor="rename-group-name">Description:</label>
          <TextInput
            id="rename-group-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
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
