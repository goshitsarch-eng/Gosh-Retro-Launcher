import { useMemo, useState, type FormEvent, type JSX } from 'react'
import { Button } from '../Common/Button'
import { TextInput } from '../Common/TextInput'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { Dialog } from './Dialog'
import { getWfwIconSrc, WFW_ICON_IDS } from '@/shells/win31/iconCatalog'
import { splitLegacyCommand } from '@shared/win31Grp'

export function NewProgramObjectDialog(): JSX.Element {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const openDialog = useUIStore((state) => state.openDialog)
  const preferredGroupId = useUIStore((state) => state.dialogData.groupId)
  const groups = useProgramStore((state) => state.groups)
  const [kind, setKind] = useState<'group' | 'item'>(groups.length ? 'item' : 'group')

  const submit = (event: FormEvent): void => {
    event.preventDefault()
    if (kind === 'group') openDialog('newGroup')
    else openDialog('newItem', { groupId: preferredGroupId ?? groups[0]?.id })
  }

  return (
    <Dialog title="New Program Object" onClose={closeDialog} width={286}>
      <form onSubmit={submit}>
        <div className="wfw-object-choice-copy">What type of object do you want to create?</div>
        <fieldset className="wfw-radio-group">
          <label>
            <input type="radio" name="object-kind" accessKey="g" checked={kind === 'group'} onChange={() => setKind('group')} />
            <span>Program <u>G</u>roup</span>
          </label>
          <label className={groups.length === 0 ? 'disabled' : ''}>
            <input type="radio" name="object-kind" accessKey="i" checked={kind === 'item'} disabled={groups.length === 0} onChange={() => setKind('item')} />
            <span>Program <u>I</u>tem</span>
          </label>
        </fieldset>
        <div className="win31-dialog-buttons">
          <Button type="submit" isDefault>OK</Button>
          <Button type="button" onClick={closeDialog}>Cancel</Button>
          <Button type="button" onClick={() => openDialog('help', { helpTopic: 'contents' })}>Help</Button>
        </div>
      </form>
    </Dialog>
  )
}

export function MoveCopyProgramItemDialog({ copy }: { copy: boolean }): JSX.Element | null {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const openDialog = useUIStore((state) => state.openDialog)
  const data = useUIStore((state) => state.dialogData)
  const groups = useProgramStore((state) => state.groups)
  const moveItem = useProgramStore((state) => state.moveItem)
  const copyItem = useProgramStore((state) => state.copyItem)
  const sourceGroupId = data.groupId
  const item = data.item
  const available = useMemo(
    () => copy ? groups : groups.filter((group) => group.id !== sourceGroupId),
    [copy, groups, sourceGroupId]
  )
  const [destination, setDestination] = useState(available[0]?.id ?? '')
  if (!sourceGroupId || !item) return null

  const submit = (event: FormEvent): void => {
    event.preventDefault()
    if (!destination) return
    if (copy) copyItem(sourceGroupId, destination, item.id)
    else moveItem(sourceGroupId, destination, item.id)
    closeDialog()
  }

  return (
    <Dialog title={`${copy ? 'Copy' : 'Move'} Program Item`} onClose={closeDialog} width={330}>
      <form onSubmit={submit}>
        <div className="wfw-dialog-prompt">{copy ? 'Copy' : 'Move'} “{item.name}” to:</div>
        <div className="win31-form-row">
          <label htmlFor="wfw-destination">Program Group:</label>
          <select id="wfw-destination" className="win31-input" value={destination} onChange={(event) => setDestination(event.target.value)} autoFocus>
            {available.map((group) => <option value={group.id} key={group.id}>{group.name}</option>)}
          </select>
        </div>
        <div className="win31-dialog-buttons">
          <Button type="submit" isDefault disabled={!destination}>OK</Button>
          <Button type="button" onClick={closeDialog}>Cancel</Button>
          <Button type="button" onClick={() => openDialog('help', { helpTopic: 'contents' })}>Help</Button>
        </div>
      </form>
    </Dialog>
  )
}

export function RunProgramDialog(): JSX.Element {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const openDialog = useUIStore((state) => state.openDialog)
  const [command, setCommand] = useState('')

  const browse = async (): Promise<void> => {
    const path = await window.electronAPI.file.selectExecutable()
    if (path) setCommand(path)
  }
  const submit = async (event: FormEvent): Promise<void> => {
    event.preventDefault()
    if (!command.trim()) return
    const parsed = splitLegacyCommand(command)
    const path = parsed.path
    const result = await window.electronAPI.program.launch({
      id: 'run-command',
      name: path.split(/[/\\]/).pop() ?? path,
      path,
      arguments: parsed.arguments,
      workingDir: '',
      icon: 'default'
    })
    if (result.success) closeDialog()
    else openDialog('confirm', {
      confirmOptions: {
        title: 'Program Manager',
        message: result.error ?? `Cannot run ${path}.`,
        onConfirm: () => undefined
      }
    })
  }

  return (
    <Dialog title="Run" onClose={closeDialog} width={392}>
      <form onSubmit={(event) => void submit(event)}>
        <div className="wfw-run-copy">Type the name of a program, folder, document, or network resource, and Program Manager will open it for you.</div>
        <div className="win31-form-row">
          <label htmlFor="wfw-run-command">Command Line:</label>
          <TextInput id="wfw-run-command" value={command} onChange={(event) => setCommand(event.target.value)} autoFocus />
        </div>
        <div className="win31-dialog-buttons">
          <Button type="submit" isDefault disabled={!command.trim()}>OK</Button>
          <Button type="button" onClick={closeDialog}>Cancel</Button>
          <Button type="button" onClick={() => void browse()}>Browse...</Button>
          <Button type="button" onClick={() => openDialog('help', { helpTopic: 'contents' })}>Help</Button>
        </div>
      </form>
    </Dialog>
  )
}

export function ProgramManagerHelpDialog(): JSX.Element {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const topic = useUIStore((state) => state.dialogData.helpTopic) ?? 'contents'
  const [query, setQuery] = useState('')
  const helpTopics = [
    'Creating program groups', 'Creating program items', 'Moving and copying items',
    'Arranging group windows', 'Changing program icons', 'Running a program', 'Keyboard commands'
  ].filter((entry) => entry.toLowerCase().includes(query.toLowerCase()))
  const headings = {
    contents: 'Program Manager Help Contents',
    search: 'Search for Help On...',
    using: 'How to Use Help'
  } as const
  return (
    <Dialog title="Program Manager Help" onClose={closeDialog} width={390}>
      <div className="wfw-help-heading">{headings[topic]}</div>
      <div className="wfw-help-well">
        {topic === 'search' ? (
          <>
            <TextInput value={query} onChange={(event) => setQuery(event.target.value)} autoFocus placeholder="Type a subject..." />
            <ul className="wfw-help-results">{helpTopics.map((entry) => <li key={entry}>{entry}</li>)}</ul>
          </>
        ) : topic === 'using'
          ? 'Choose a menu command or select an object, then choose Help for information about that operation. Press F10 to enter menu mode and use the arrow keys to move.'
          : 'Use Program Manager to organize programs into groups. Double-click a program icon to run it. Use File to create, move, copy, delete, and inspect objects.'}
      </div>
      <div className="win31-dialog-buttons">
        <Button type="button" isDefault onClick={closeDialog}>OK</Button>
      </div>
    </Dialog>
  )
}

export function ChangeIconDialog(): JSX.Element | null {
  const openDialog = useUIStore((state) => state.openDialog)
  const data = useUIStore((state) => state.dialogData)
  const updateItem = useProgramStore((state) => state.updateItem)
  const item = data.item
  const groupId = data.groupId
  const [icon, setIcon] = useState(item?.win31Icon ?? item?.icon ?? 'default')
  if (!item || !groupId) return null

  const browse = async (): Promise<void> => {
    const selected = await window.electronAPI.file.selectIcon()
    if (!selected) return
    const info = await window.electronAPI.app.getInfo(selected)
    setIcon(info.win31Icon ?? info.icon ?? icon)
  }
  const returnToProperties = (nextIcon = icon): void => {
    openDialog('itemProperties', { groupId, item: { ...item, win31Icon: nextIcon } })
  }
  const submit = (event: FormEvent): void => {
    event.preventDefault()
    updateItem(groupId, item.id, { win31Icon: icon })
    returnToProperties(icon)
  }
  return (
    <Dialog title="Change Icon" onClose={() => returnToProperties(item.win31Icon ?? item.icon)} width={360}>
      <form onSubmit={submit}>
        <div className="wfw-change-icon-copy">Select an icon for this program item:</div>
        <div className="wfw-change-icon-grid" role="listbox" aria-label="Program icons">
          {WFW_ICON_IDS.map((iconId) => (
            <button type="button" role="option" aria-selected={icon === iconId} key={iconId}
              className={`win31-icon-choice ${icon === iconId ? 'selected' : ''}`}
              onClick={() => setIcon(iconId)} title={iconId}>
              <img src={getWfwIconSrc(iconId, 1)} alt="" />
            </button>
          ))}
        </div>
        <div className="win31-dialog-buttons">
          <Button type="submit" isDefault>OK</Button>
          <Button type="button" onClick={() => returnToProperties(item.win31Icon ?? item.icon)}>Cancel</Button>
          <Button type="button" onClick={() => void browse()}>Browse...</Button>
          <Button type="button" onClick={() => openDialog('help', { helpTopic: 'contents' })}>Help</Button>
        </div>
      </form>
    </Dialog>
  )
}

export function ExitWindowsDialog(): JSX.Element {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const openDialog = useUIStore((state) => state.openDialog)
  return (
    <Dialog title="Exit Windows" onClose={closeDialog} width={330}>
      <div className="wfw-exit-composition">
        <img src={getWfwIconSrc('question', 1)} alt="" />
        <span>This will end your Program Manager session.</span>
      </div>
      <div className="win31-dialog-buttons">
        <Button type="button" isDefault onClick={() => void window.electronAPI.window.quit()}>OK</Button>
        <Button type="button" onClick={closeDialog}>Cancel</Button>
        <Button type="button" onClick={() => openDialog('help', { helpTopic: 'contents' })}>Help</Button>
      </div>
    </Dialog>
  )
}
