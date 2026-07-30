import React, { useState, useCallback, useEffect } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { getIconSrc, BUILTIN_ICONS } from '@/utils/icons'
import { LAUNCH_GROUP_OPTIONS, formatLaunchGroup } from '@/utils/launchGroups'
import type { ProgramRunMode } from '@shared/types'
import { getWfwIconSrc, WFW_ICON_IDS } from '@/shells/win31/iconCatalog'

export const ItemPropertiesDialog: React.FC = () => {
  const dialogData = useUIStore((state) => state.dialogData)
  const closeDialog = useUIStore((state) => state.closeDialog)
  const openDialog = useUIStore((state) => state.openDialog)
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
  const [argumentsValue, setArgumentsValue] = useState(existingItem?.arguments || '')
  const [environment, setEnvironment] = useState(existingItem?.environment || '')
  const [runMode, setRunMode] = useState<ProgramRunMode>(existingItem?.runMode ?? (existingItem?.runMinimized ? 'minimized' : 'normal'))
  const [icon, setIcon] = useState(existingItem?.icon || 'default')
  const [win31Icon, setWin31Icon] = useState(existingItem?.win31Icon || existingItem?.icon || 'default')
  const [launchGroup, setLaunchGroup] = useState(existingItem?.launchGroup ?? 0)
  const [shortcutKey, setShortcutKey] = useState(existingItem?.shortcutKey ?? '')
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
      if (appInfo.win31Icon && (win31Icon === 'default' || win31Icon === 'default-item.png')) setWin31Icon(appInfo.win31Icon)
      if (!workingDir && appInfo.workingDir) setWorkingDir(appInfo.workingDir)
      if (!argumentsValue && appInfo.arguments) setArgumentsValue(appInfo.arguments)
    } catch {
      if (!name) {
        const fileName = selectedPath.split(/[/\\]/).pop() || ''
        setName(fileName.replace(/\.[^/.]+$/, ''))
      }
    }
  }, [argumentsValue, name, icon, win31Icon, workingDir])

  const handleSubmit = useCallback((event: React.FormEvent) => {
    event.preventDefault()
    if (!name.trim() || !path.trim() || !selectedGroupId) return
    const values = {
      name: name.trim(),
      path: path.trim(),
      workingDir: workingDir.trim(),
      arguments: argumentsValue.trim(),
      environment: environment.trim(),
      runMode,
      icon,
      win31Icon,
      launchGroup,
      shortcutKey: shortcutKey.trim(),
      runMinimized: runMode === 'minimized'
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
  }, [name, path, workingDir, argumentsValue, environment, runMode, icon, win31Icon, launchGroup, shortcutKey, selectedGroupId, isEditing, existingItem,
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
  const win31Icons = WFW_ICON_IDS.filter((candidate) =>
    !iconSearch || candidate.toLowerCase().includes(iconSearch.toLowerCase())
  )
  const iconSource = shell === 'win31' ? getWfwIconSrc(win31Icon, 1) : getIconSrc(icon)
  const submitDisabled = !name.trim() || !path.trim() || !selectedGroupId

  return (
    <Dialog title={isEditing ? 'Program Item Properties' : 'New Program Item'} onClose={closeDialog} width={470}>
      <form onSubmit={handleSubmit} className="win31-properties-layout">
        <div className="win31-properties-fields">
          {shell === 'win95' && groups.length > 1 && (
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
            <label htmlFor="item-arguments">Arguments:</label>
            <TextInput id="item-arguments" value={argumentsValue} onChange={(event) => setArgumentsValue(event.target.value)} />
          </div>
          <div className="win31-form-row win31-form-row-top">
            <label htmlFor="item-environment">Environment:</label>
            <textarea id="item-environment" className="win31-input" rows={3} value={environment}
              placeholder="KEY=VALUE (one per line)" onChange={(event) => setEnvironment(event.target.value)} />
          </div>
          {shell === 'win95' ? (
            <div className="win31-form-row">
              <label htmlFor="item-launch-group">Launch Group:</label>
              <select id="item-launch-group" className="win31-input" value={launchGroup}
                onChange={(event) => setLaunchGroup(Number(event.target.value))}>
                {LAUNCH_GROUP_OPTIONS.map((value) => <option key={value} value={value}>{formatLaunchGroup(value)}</option>)}
              </select>
            </div>
          ) : (
            <>
              <div className="win31-form-row">
                <label htmlFor="item-shortcut">Shortcut Key:</label>
                <TextInput id="item-shortcut" value={shortcutKey} onChange={(event) => setShortcutKey(event.target.value)} />
              </div>
              <div className="win31-form-row">
                <label htmlFor="item-run-mode">Run:</label>
                <select id="item-run-mode" className="win31-input" value={runMode}
                  onChange={(event) => setRunMode(event.target.value as ProgramRunMode)}>
                  <option value="normal">Normal Window</option>
                  <option value="minimized">Minimized</option>
                  <option value="maximized">Maximized</option>
                </select>
              </div>
              <div className="win31-form-row">
                <label htmlFor="item-launch-group">Launch Group:</label>
                <select id="item-launch-group" className="win31-input" value={launchGroup}
                  onChange={(event) => setLaunchGroup(Number(event.target.value))}>
                  {LAUNCH_GROUP_OPTIONS.map((value) => <option key={value} value={value}>{formatLaunchGroup(value)}</option>)}
                </select>
              </div>
            </>
          )}
          <div className="win31-form-row win31-icon-preview-row">
            <label>Icon:</label>
            <div className="win31-icon-preview-well"><img src={iconSource} alt="Selected icon" width={32} height={32} /></div>
          </div>
          {showIconPicker && (
            <div className="win31-icon-picker-panel">
              <TextInput value={iconSearch} onChange={(event) => setIconSearch(event.target.value)} placeholder="Filter icons..." />
              <div className="win31-icon-picker" role="listbox" aria-label="Program icons">
                {shell === 'win31' ? win31Icons.map((iconId) => (
                  <button type="button" key={iconId}
                    className={`win31-icon-choice ${icon === iconId ? 'selected' : ''}`}
                    onClick={() => { setWin31Icon(iconId); setIcon(iconId) }} title={iconId}
                    aria-label={iconId} aria-selected={win31Icon === iconId} role="option">
                    <img src={getWfwIconSrc(iconId, 1)} alt="" width={32} height={32} />
                  </button>
                )) : filteredIcons.map((iconOption) => (
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
          <Button type="button" onClick={() => {
            if (isEditing && existingItem) {
              openDialog('changeIcon', {
                groupId: resolvedGroupId,
                item: {
                  ...existingItem,
                  name,
                  path,
                  workingDir,
                  arguments: argumentsValue,
                  environment,
                  runMode,
                  shortcutKey,
                  icon,
                  win31Icon,
                  launchGroup
                }
              })
            } else {
              setShowIconPicker((shown) => !shown)
            }
          }}>
            {showIconPicker ? 'Hide Icons' : 'Change Icon...'}
          </Button>
          {isEditing && shell === 'win95' && <Button type="button" onClick={handleDelete}>Delete</Button>}
          {shell === 'win31' && <Button type="button" onClick={() => openDialog('help', { helpTopic: 'contents' })}>Help</Button>}
        </div>
      </form>
    </Dialog>
  )
}
