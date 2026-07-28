import React, { useState, useCallback, useEffect } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { getIconSrc, BUILTIN_ICONS } from '@/utils/icons'
import { LAUNCH_GROUP_OPTIONS, formatLaunchGroup } from '@/utils/launchGroups'

export const ItemPropertiesDialog: React.FC = () => {
  const dialogData = useUIStore((state) => state.dialogData)
  const closeDialog = useUIStore((state) => state.closeDialog)
  const addItem = useProgramStore((state) => state.addItem)
  const updateItem = useProgramStore((state) => state.updateItem)
  const deleteItem = useProgramStore((state) => state.deleteItem)
  const moveItem = useProgramStore((state) => state.moveItem)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const groups = useProgramStore((state) => state.groups)
  const shell = useProgramStore((state) => state.settings.shell)
  const openWindow = useMDIStore((state) => state.openWindow)

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
  const [icon, setIcon] = useState(existingItem?.icon || 'default')
  const [launchGroup, setLaunchGroup] = useState(existingItem?.launchGroup ?? 0)
  const [showIconPicker, setShowIconPicker] = useState(false)
  const [iconSearch, setIconSearch] = useState('')

  useEffect(() => {
    if (!selectedGroupId && resolvedGroupId) setSelectedGroupId(resolvedGroupId)
  }, [resolvedGroupId, selectedGroupId])

  const handleBrowsePath = useCallback(async () => {
    const selectedPath = await window.electronAPI.file.selectExecutable()
    if (!selectedPath) return
    setPath(selectedPath)
    try {
      const appInfo = await window.electronAPI.app.getInfo(selectedPath)
      if (!name && appInfo.name) setName(appInfo.name)
      if (appInfo.icon && (icon === 'default' || icon === 'default-item.png')) setIcon(appInfo.icon)
      if (!workingDir && appInfo.workingDir) setWorkingDir(appInfo.workingDir)
    } catch {
      if (!name) {
        const fileName = selectedPath.split(/[/\\]/).pop() || ''
        setName(fileName.replace(/\.[^/.]+$/, ''))
      }
    }
  }, [name, icon, workingDir])

  const handleSubmit = useCallback((event: React.FormEvent) => {
    event.preventDefault()
    if (!name.trim() || !path.trim() || !selectedGroupId) return
    const values = {
      name: name.trim(),
      path: path.trim(),
      workingDir: workingDir.trim(),
      icon,
      launchGroup
    }
    if (isEditing && existingItem) {
      updateItem(resolvedGroupId, existingItem.id, values)
      if (resolvedGroupId && selectedGroupId !== resolvedGroupId) {
        moveItem(resolvedGroupId, selectedGroupId, existingItem.id)
      }
    } else {
      addItem(selectedGroupId, values)
    }
    if (shell === 'win95') {
      updateGroupWindowState(selectedGroupId, { minimized: false })
      openWindow(selectedGroupId)
    }
    closeDialog()
  }, [name, path, workingDir, icon, launchGroup, selectedGroupId, isEditing, existingItem,
    resolvedGroupId, addItem, updateItem, moveItem, shell, updateGroupWindowState, openWindow, closeDialog])

  const handleDelete = useCallback(() => {
    if (existingItem && resolvedGroupId) {
      deleteItem(resolvedGroupId, existingItem.id)
      closeDialog()
    }
  }, [existingItem, resolvedGroupId, deleteItem, closeDialog])

  const filteredIcons = BUILTIN_ICONS.filter((candidate) =>
    !iconSearch || candidate.name.toLowerCase().includes(iconSearch.toLowerCase())
  )
  const submitDisabled = !name.trim() || !path.trim() || !selectedGroupId

  return (
    <Dialog title={isEditing ? 'Program Item Properties' : 'New Program Item'} onClose={closeDialog} width={470}>
      <form onSubmit={handleSubmit} className="win31-properties-layout">
        <div className="win31-properties-fields">
          {groups.length > 1 && (
            <div className="win31-form-row">
              <label htmlFor="item-group">Program Group:</label>
              <select id="item-group" className="win31-input" value={selectedGroupId}
                onChange={(event) => setSelectedGroupId(event.target.value)}>
                {groups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}
              </select>
            </div>
          )}
          <div className="win31-form-row">
            <label htmlFor="item-name">Description:</label>
            <TextInput id="item-name" value={name} onChange={(event) => setName(event.target.value)} autoFocus />
          </div>
          <div className="win31-form-row">
            <label htmlFor="item-path">Command Line:</label>
            <TextInput id="item-path" value={path} onChange={(event) => setPath(event.target.value)} />
          </div>
          <div className="win31-form-row">
            <label htmlFor="item-workdir">Working Directory:</label>
            <TextInput id="item-workdir" value={workingDir} onChange={(event) => setWorkingDir(event.target.value)} />
          </div>
          <div className="win31-form-row">
            <label htmlFor="item-launch-group">Launch Group:</label>
            <select id="item-launch-group" className="win31-input" value={launchGroup}
              onChange={(event) => setLaunchGroup(Number(event.target.value))}>
              {LAUNCH_GROUP_OPTIONS.map((value) => <option key={value} value={value}>{formatLaunchGroup(value)}</option>)}
            </select>
          </div>
          <div className="win31-form-row win31-icon-preview-row">
            <label>Icon:</label>
            <div className="win31-icon-preview-well"><img src={getIconSrc(icon)} alt="Selected icon" width={32} height={32} /></div>
          </div>
          {showIconPicker && (
            <div className="win31-icon-picker-panel">
              <TextInput value={iconSearch} onChange={(event) => setIconSearch(event.target.value)} placeholder="Filter icons..." />
              <div className="win31-icon-picker" role="listbox" aria-label="Program icons">
                {filteredIcons.map((iconOption) => (
                  <button type="button" key={iconOption.id}
                    className={`win31-icon-choice ${icon === iconOption.id ? 'selected' : ''}`}
                    onClick={() => setIcon(iconOption.id)} title={iconOption.name}
                    aria-label={iconOption.name} aria-selected={icon === iconOption.id} role="option">
                    <img src={iconOption.icon} alt="" width={32} height={32} />
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
        <div className="win31-properties-buttons">
          <Button type="submit" isDefault disabled={submitDisabled}>OK</Button>
          <Button type="button" onClick={closeDialog}>Cancel</Button>
          <Button type="button" onClick={handleBrowsePath}>Browse...</Button>
          <Button type="button" onClick={() => setShowIconPicker((shown) => !shown)}>
            {showIconPicker ? 'Hide Icons' : 'Change Icon...'}
          </Button>
          {isEditing && <Button type="button" onClick={handleDelete}>Delete</Button>}
        </div>
      </form>
    </Dialog>
  )
}
