import React, { useState, useCallback, useEffect } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { getIconSrc, BUILTIN_ICONS } from '@/utils/icons'
import { LAUNCH_GROUP_OPTIONS, formatLaunchGroup } from '@/utils/launchGroups'

export const ItemPropertiesDialog: React.FC = () => {
  const { dialogData, closeDialog } = useUIStore()
  const { addItem, updateItem, deleteItem, moveItem } = useProgramStore()
  const groups = useProgramStore((state) => state.groups)

  const isEditing = !!dialogData.item
  const existingItem = dialogData.item

  const resolvedGroupId =
    dialogData.groupId ||
    (existingItem
      ? groups.find((group) => group.items.some((item) => item.id === existingItem.id))?.id
      : groups[0]?.id) ||
    ''

  const [selectedGroupId, setSelectedGroupId] = useState(resolvedGroupId)
  const [name, setName] = useState(existingItem?.name || '')
  const [path, setPath] = useState(existingItem?.path || '')
  const [workingDir, setWorkingDir] = useState(existingItem?.workingDir || '')
  const [shortcutKey, setShortcutKey] = useState(existingItem?.shortcutKey || '')
  const [icon, setIcon] = useState(existingItem?.icon || 'default')
  const [launchGroup, setLaunchGroup] = useState(existingItem?.launchGroup ?? 0)
  const [showIconPicker, setShowIconPicker] = useState(false)

  useEffect(() => {
    if (!selectedGroupId && resolvedGroupId) {
      setSelectedGroupId(resolvedGroupId)
    }
  }, [resolvedGroupId, selectedGroupId])

  const handleBrowsePath = useCallback(async () => {
    const selectedPath = await window.electronAPI.file.selectExecutable()
    if (selectedPath) {
      setPath(selectedPath)
      // Set name from filename if empty
      if (!name) {
        const fileName = selectedPath.split(/[/\\]/).pop() || ''
        setName(fileName.replace(/\.[^/.]+$/, ''))
      }
    }
  }, [name])

  const handleSubmit = useCallback(
    (event: React.FormEvent) => {
      event.preventDefault()
      if (!name.trim() || !path.trim() || !selectedGroupId) return

      if (isEditing && existingItem) {
        updateItem(resolvedGroupId, existingItem.id, {
          name: name.trim(),
          path: path.trim(),
          workingDir: workingDir.trim(),
          shortcutKey: shortcutKey.trim(),
          icon,
          launchGroup
        })
        if (resolvedGroupId && selectedGroupId !== resolvedGroupId) {
          moveItem(resolvedGroupId, selectedGroupId, existingItem.id)
        }
      } else {
        addItem(selectedGroupId, {
          name: name.trim(),
          path: path.trim(),
          workingDir: workingDir.trim(),
          shortcutKey: shortcutKey.trim(),
          icon,
          launchGroup
        })
      }
      closeDialog()
    },
    [
      name,
      path,
      workingDir,
      shortcutKey,
      icon,
      launchGroup,
      selectedGroupId,
      isEditing,
      existingItem,
      resolvedGroupId,
      addItem,
      updateItem,
      moveItem,
      closeDialog
    ]
  )

  const handleDelete = useCallback(() => {
    if (existingItem && resolvedGroupId) {
      deleteItem(resolvedGroupId, existingItem.id)
      closeDialog()
    }
  }, [existingItem, resolvedGroupId, deleteItem, closeDialog])

  return (
    <Dialog
      title={isEditing ? 'Program Item Properties' : 'New Program Item'}
      onClose={closeDialog}
      width={450}
    >
      <form onSubmit={handleSubmit}>
        {groups.length > 1 && (
          <div className="win31-form-row">
            <label htmlFor="item-group">Program Group:</label>
            <select
              id="item-group"
              className="win31-input"
              value={selectedGroupId}
              onChange={(e) => setSelectedGroupId(e.target.value)}
            >
              {groups.map((group) => (
                <option key={group.id} value={group.id}>
                  {group.name}
                </option>
              ))}
            </select>
          </div>
        )}

        <div className="win31-form-row">
          <label htmlFor="item-name">Description:</label>
          <TextInput
            id="item-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
          />
        </div>

        <div className="win31-form-row">
          <label htmlFor="item-path">Command Line:</label>
          <TextInput
            id="item-path"
            value={path}
            onChange={(e) => setPath(e.target.value)}
          />
          <Button type="button" onClick={handleBrowsePath}>
            Browse...
          </Button>
        </div>

        <div className="win31-form-row">
          <label htmlFor="item-workdir">Working Directory:</label>
          <TextInput
            id="item-workdir"
            value={workingDir}
            onChange={(e) => setWorkingDir(e.target.value)}
          />
        </div>

        <div className="win31-form-row">
          <label htmlFor="item-shortcut">Shortcut Key:</label>
          <TextInput
            id="item-shortcut"
            value={shortcutKey}
            onChange={(e) => setShortcutKey(e.target.value)}
            placeholder="e.g., Ctrl+Alt+F"
            style={{ width: 150 }}
          />
        </div>

        <div className="win31-form-row">
          <label htmlFor="item-launch-group">Launch Group:</label>
          <select
            id="item-launch-group"
            className="win31-input"
            value={launchGroup}
            onChange={(e) => setLaunchGroup(Number(e.target.value))}
            style={{ width: 150 }}
          >
            {LAUNCH_GROUP_OPTIONS.map((value) => (
              <option key={value} value={value}>
                {formatLaunchGroup(value)}
              </option>
            ))}
          </select>
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
          <Button
            type="submit"
            isDefault
            disabled={!name.trim() || !path.trim() || !selectedGroupId}
          >
            OK
          </Button>
          <Button type="button" onClick={closeDialog}>
            Cancel
          </Button>
          {isEditing && (
            <Button type="button" onClick={handleDelete}>
              Delete
            </Button>
          )}
        </div>
      </form>
    </Dialog>
  )
}
