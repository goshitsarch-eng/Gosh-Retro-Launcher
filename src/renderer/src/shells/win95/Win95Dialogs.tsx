import {
  useEffect,
  useId,
  useRef,
  useState,
  type FormEvent,
  type JSX,
  type ReactNode
} from 'react'
import type { ProgramItem } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { getWin95IconSrc } from './iconCatalog'
import { useWin95Scale } from './Win95ScaleContext'
import { useWin95InputHandler } from './Win95InputController'
import { Win95BitmapText } from './bitmapText'
import {
  Win95Button,
  Win95Checkbox,
  Win95Glyph,
  Win95Radio,
  Win95Select,
  Win95TextInput
} from './Win95Primitives'
import { useWin95WindowStore } from './windowStore'
import { WIN95_METRICS } from './tokens'
import { resolveWin95DialogKey } from './dialogState'
import { applyShellSettingsTransaction } from '@/utils/shellSwitch'

interface Win95DialogProps {
  title: string
  onClose: () => void
  children: ReactNode
  width?: number
  height?: number
  contextHelp?: string
}

function Win95Dialog({ title, onClose, children, width = 360, height, contextHelp }: Win95DialogProps): JSX.Element {
  const id = useId()
  const frameRef = useRef<HTMLDivElement>(null)
  const { toLogicalDelta } = useWin95Scale()
  const [offset, setOffset] = useState({ x: 0, y: 0 })
  const [helpOpen, setHelpOpen] = useState(false)

  useEffect(() => {
    const frame = frameRef.current
    const focusable = frame?.querySelector<HTMLElement>('[data-dialog-body] [data-initial-focus]') ?? frame?.querySelector<HTMLElement>('[data-dialog-body] input:not([disabled]), [data-dialog-body] button:not([disabled]), [data-dialog-body] select:not([disabled]), [data-dialog-body] textarea:not([disabled]), [data-dialog-body] [tabindex="0"]')
    focusable?.focus()
  }, [])

  useWin95InputHandler('modal', `dialog-${id}`, (event) => {
    const frame = frameRef.current
    if (!frame) return false
    const defaultButton = frame.querySelector<HTMLButtonElement>('[data-dialog-body] .win95-control-button.default:not(:disabled), [data-dialog-body] button.default:not(:disabled)')
    const action = resolveWin95DialogKey(event, !!defaultButton, document.activeElement instanceof HTMLButtonElement, document.activeElement instanceof HTMLTextAreaElement)
    if (action === 'cancel') { onClose(); return true }
    if (action === 'advance-focus' || action === 'reverse-focus') {
      const elements = [...frame.querySelectorAll<HTMLElement>('[data-dialog-body] input:not([disabled]), [data-dialog-body] button:not([disabled]), [data-dialog-body] select:not([disabled]), [data-dialog-body] textarea:not([disabled]), [data-dialog-body] [tabindex="0"]')]
      if (!elements.length) return true
      const index = elements.indexOf(document.activeElement as HTMLElement)
      const next = action === 'reverse-focus' ? (index <= 0 ? elements.length - 1 : index - 1) : (index >= elements.length - 1 ? 0 : index + 1)
      elements[next].focus(); return true
    }
    if (event.altKey && event.key.length === 1) {
      const access = event.key.toLowerCase()
      const text = [...frame.querySelectorAll<HTMLElement>(`[data-access-key="${CSS.escape(access)}"]`)].at(-1)
      const owner = text?.closest<HTMLElement>('button, label, [role="tab"]')
      if (owner instanceof HTMLButtonElement) owner.click()
      else if (owner instanceof HTMLLabelElement) owner.querySelector<HTMLElement>('input, select, textarea, button')?.focus()
      return !!text
    }
    if (event.key === 'Enter' && document.activeElement instanceof HTMLButtonElement) { document.activeElement.click(); return true }
    if (action === 'default' && defaultButton) { defaultButton.click(); return true }
    return false
  })

  const drag = (event: React.PointerEvent): void => {
    if (event.button !== 0 || (event.target as HTMLElement).closest('button')) return
    event.preventDefault()
    const start = { x: event.clientX, y: event.clientY, offset }
    const move = (pointer: PointerEvent): void => setOffset({
      x: Math.round(start.offset.x + toLogicalDelta(pointer.clientX - start.x)),
      y: Math.round(start.offset.y + toLogicalDelta(pointer.clientY - start.y))
    })
    const end = (): void => {
      document.removeEventListener('pointermove', move)
      document.removeEventListener('pointerup', end)
    }
    document.addEventListener('pointermove', move)
    document.addEventListener('pointerup', end)
  }

  return <>
    <div className="win95-dialog-overlay" role="presentation">
      <div ref={frameRef} className="win95-dialog" style={{ width, ...(height ? { height } : {}), transform: `translate(${offset.x}px, ${offset.y}px)` }} role="dialog" aria-modal="true" aria-label={title}>
        <div className="win95-dialog-caption" onPointerDown={drag}>
          <span><Win95BitmapText text={title} bold color="#ffffff" maxWidth={Math.max(1, width - (contextHelp ? 49 : 31))} /></span>
          {contextHelp && <button type="button" tabIndex={-1} aria-label="Context Help" onClick={() => setHelpOpen(true)}><Win95Glyph name="help" /></button>}
          <button type="button" tabIndex={-1} aria-label="Close" onClick={onClose}><Win95Glyph name="close" /></button>
        </div>
        <div className="win95-dialog-body" data-dialog-body>{children}</div>
      </div>
    </div>
    {helpOpen && <Win95Dialog title="Help" onClose={() => setHelpOpen(false)} width={330}>
      <div className="win95-message"><img src={getWin95IconSrc('information', 'large')} alt="" /><Win95BitmapText text={contextHelp ?? ''} wrap maxWidth={245} /></div>
      <div className="win95-dialog-buttons"><Win95Button label="OK" defaultButton onClick={() => setHelpOpen(false)} /></div>
    </Win95Dialog>}
  </>
}

function DialogButtons({ onCancel, submitLabel = '&OK', apply, applyDisabled = false, extra }: {
  onCancel: () => void
  submitLabel?: string
  apply?: () => void
  applyDisabled?: boolean
  extra?: ReactNode
}): JSX.Element {
  return <div className="win95-dialog-buttons">{extra}<Win95Button type="submit" label={submitLabel} defaultButton /><Win95Button type="button" label="&Cancel" onClick={onCancel} />{apply && <Win95Button type="button" label="&Apply" disabled={applyDisabled} onClick={apply} />}</div>
}

function FormRow({ label, children }: { label: string; children: ReactNode }): JSX.Element {
  return <label className="win95-form-row"><Win95BitmapText text={label} />{children}</label>
}

export function Win95DialogManager(): JSX.Element | null {
  const activeDialog = useUIStore((state) => state.activeDialog)
  const data = useUIStore((state) => state.dialogData)
  const close = useUIStore((state) => state.closeDialog)
  if (!activeDialog) return null
  if (activeDialog === 'newGroup') return <NewGroupDialog onClose={close} />
  if (activeDialog === 'newItem') return <ShortcutWizard onClose={close} />
  if (activeDialog === 'itemProperties') return <ItemPropertySheet onClose={close} />
  if (activeDialog === 'newUrl') return <NewUrlDialog onClose={close} />
  if (activeDialog === 'groupProperties') return <GroupPropertySheet onClose={close} />
  if (activeDialog === 'run') return <RunDialog onClose={close} />
  if (activeDialog === 'help') return <HelpDialog onClose={close} />
  if (activeDialog === 'about') return <AboutDialog onClose={close} />
  if (activeDialog === 'confirm') return <ConfirmDialog onClose={close} />
  if (activeDialog === 'unavailable') return <MessageDialog title={data.title ?? 'Gosh 95'} message={data.message ?? 'This feature is not available.'} onClose={close} symbol="warning" />
  if (activeDialog === 'exitWindows') return <ShutDownDialog onClose={close} />
  if (activeDialog === 'settings') return <OpenTools onClose={close} />
  return null
}

function OpenTools({ onClose }: { onClose: () => void }): null {
  useEffect(() => { void window.electronAPI.app.openLauncherTools(); onClose() }, [onClose])
  return null
}

function NewGroupDialog({ onClose }: { onClose: () => void }): JSX.Element {
  const data = useUIStore((state) => state.dialogData)
  const openDialog = useUIStore((state) => state.openDialog)
  const addGroup = useProgramStore((state) => state.addGroup)
  const openGroup = useWin95WindowStore((state) => state.openGroup)
  const [name, setName] = useState('New Folder')
  const submit = (event: FormEvent): void => {
    event.preventDefault(); if (!name.trim()) return
    const id = addGroup(name.trim()); openGroup(id)
    if (data.openItemAfterCreate) openDialog('newItem', { groupId: id })
    else if (data.openUrlAfterCreate) openDialog('newUrl', { groupId: id })
    else onClose()
  }
  return <Win95Dialog title="Create New Folder" onClose={onClose} width={340} height={128}><form onSubmit={submit}>
    <Win95BitmapText text="Type a name for the new folder:" />
    <Win95TextInput value={name} onChange={(event) => setName(event.target.value)} />
    <DialogButtons onCancel={onClose} />
  </form></Win95Dialog>
}

function ShortcutWizard({ onClose }: { onClose: () => void }): JSX.Element {
  const data = useUIStore((state) => state.dialogData)
  const groups = useProgramStore((state) => state.groups)
  const addItem = useProgramStore((state) => state.addItem)
  const openGroup = useWin95WindowStore((state) => state.openGroup)
  const [step, setStep] = useState(0)
  const [groupId, setGroupId] = useState(data.groupId ?? groups[0]?.id ?? '')
  const [command, setCommand] = useState('')
  const [workingDir, setWorkingDir] = useState('')
  const [name, setName] = useState('New Shortcut')
  const [icon, setIcon] = useState('new-shortcut')
  const browse = async (): Promise<void> => {
    const path = await window.electronAPI.file.selectExecutable(); if (!path) return
    setCommand(path)
    try { const info = await window.electronAPI.app.getInfo(path); setName(info.name || 'New Shortcut'); setWorkingDir(info.workingDir ?? ''); if (info.icon) setIcon(info.icon) } catch { /* typed path stays valid */ }
  }
  const finish = (): void => {
    if (!groupId || !name.trim() || !command.trim()) return
    addItem(groupId, { name: name.trim(), path: command.trim(), icon, workingDir: workingDir.trim() })
    openGroup(groupId); onClose()
  }
  return <Win95Dialog title="Create Shortcut" onClose={onClose} width={430} height={250} contextHelp="The Create Shortcut wizard adds a launcher item without modifying the selected application.">
    <div className="win95-wizard-page">
      <img src={getWin95IconSrc(step === 0 ? 'new-shortcut' : icon, 'large')} alt="" />
      {step === 0 ? <div><h2><Win95BitmapText text="What item would you like to create a shortcut for?" bold wrap maxWidth={315} /></h2>
        <Win95BitmapText text="Type the location of the item, or click Browse." wrap maxWidth={315} />
        <div className="win95-wizard-command"><Win95TextInput value={command} onChange={(event) => setCommand(event.target.value)} /><Win95Button type="button" label="&Browse..." onClick={() => void browse()} /></div>
      </div> : <div><h2><Win95BitmapText text="Select a title and program group" bold /></h2>
        <FormRow label="&Name:"><Win95TextInput value={name} onChange={(event) => setName(event.target.value)} /></FormRow>
        <FormRow label="&Program group:"><Win95Select value={groupId} onChange={(event) => setGroupId(event.target.value)}>{groups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}</Win95Select></FormRow>
      </div>}
    </div>
    <div className="win95-wizard-buttons">
      <Win95Button label="< &Back" disabled={step === 0} onClick={() => setStep(0)} />
      {step === 0 ? <Win95Button label="&Next >" defaultButton disabled={!command.trim()} onClick={() => setStep(1)} /> : <Win95Button label="&Finish" defaultButton disabled={!name.trim() || !groupId} onClick={finish} />}
      <Win95Button label="&Cancel" onClick={onClose} />
    </div>
  </Win95Dialog>
}

function PropertyTabs({ tab, setTab, labels }: { tab: string; setTab: (tab: string) => void; labels: Array<{ id: string; label: string }> }): JSX.Element {
  return <div className="win95-property-tabs" role="tablist">{labels.map((item) => <button type="button" role="tab" key={item.id} aria-selected={tab === item.id} className={tab === item.id ? 'selected' : ''} onClick={() => setTab(item.id)}><Win95BitmapText text={item.label} /></button>)}</div>
}

function ItemPropertySheet({ onClose }: { onClose: () => void }): JSX.Element {
  const data = useUIStore((state) => state.dialogData)
  const groups = useProgramStore((state) => state.groups)
  const updateItem = useProgramStore((state) => state.updateItem)
  const moveItem = useProgramStore((state) => state.moveItem)
  const item = data.item
  const initialGroup = data.groupId ?? groups.find((group) => item && group.items.some((candidate) => candidate.id === item.id))?.id ?? ''
  const [tab, setTab] = useState('shortcut')
  const persistedGroup = useRef(initialGroup)
  const [groupId, setGroupId] = useState(initialGroup)
  const [name, setName] = useState(item?.name ?? '')
  const [command, setCommand] = useState(item?.path ?? '')
  const [workingDir, setWorkingDir] = useState(item?.workingDir ?? '')
  const [argumentsValue, setArgumentsValue] = useState(item?.arguments ?? '')
  const [runMode, setRunMode] = useState(item?.runMode ?? 'normal')
  const [dirty, setDirty] = useState(false)
  if (!item) return <MessageDialog title="Properties" message="The shortcut no longer exists." onClose={onClose} symbol="warning" />
  const apply = (): void => {
    if (!name.trim() || !command.trim() || !groupId) return
    updateItem(persistedGroup.current, item.id, { name: name.trim(), path: command.trim(), workingDir: workingDir.trim(), arguments: argumentsValue.trim(), runMode })
    if (groupId !== persistedGroup.current) moveItem(persistedGroup.current, groupId, item.id)
    persistedGroup.current = groupId
    setDirty(false)
  }
  const change = <T,>(setter: (value: T) => void, value: T): void => { setter(value); setDirty(true) }
  return <Win95Dialog title={`${item.name} Properties`} onClose={onClose} width={420} height={285}>
    <PropertyTabs tab={tab} setTab={setTab} labels={[{ id: 'shortcut', label: '&Shortcut' }, { id: 'program', label: '&Program' }]} />
    <div className="win95-property-page">
      {tab === 'shortcut' ? <>
        <div className="win95-properties-heading"><img src={getWin95IconSrc(item.icon, 'large')} alt="" /><Win95BitmapText text={item.name} bold /></div>
        <FormRow label="&Description:"><Win95TextInput value={name} onChange={(event) => change(setName, event.target.value)} /></FormRow>
        <FormRow label="&Command line:"><Win95TextInput value={command} onChange={(event) => change(setCommand, event.target.value)} /></FormRow>
        <FormRow label="&Working directory:"><Win95TextInput value={workingDir} onChange={(event) => change(setWorkingDir, event.target.value)} /></FormRow>
        <FormRow label="Program &group:"><Win95Select value={groupId} onChange={(event) => change(setGroupId, event.target.value)}>{groups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}</Win95Select></FormRow>
      </> : <>
        <FormRow label="&Arguments:"><Win95TextInput value={argumentsValue} onChange={(event) => change(setArgumentsValue, event.target.value)} /></FormRow>
        <FormRow label="&Run:"><Win95Select value={runMode} onChange={(event) => change(setRunMode, event.target.value as typeof runMode)}><option value="normal">Normal window</option><option value="minimized">Minimized</option><option value="maximized">Maximized</option></Win95Select></FormRow>
        <Win95Checkbox label="Close on e&xit" checked disabled />
      </>}
    </div>
    <form onSubmit={(event) => { event.preventDefault(); apply(); onClose() }}><DialogButtons onCancel={onClose} apply={apply} applyDisabled={!dirty} /></form>
  </Win95Dialog>
}

function GroupPropertySheet({ onClose }: { onClose: () => void }): JSX.Element {
  const group = useUIStore((state) => state.dialogData.group)
  const updateGroup = useProgramStore((state) => state.updateGroup)
  const [name, setName] = useState(group?.name ?? '')
  const [dirty, setDirty] = useState(false)
  if (!group) return <MessageDialog title="Properties" message="The folder no longer exists." onClose={onClose} symbol="warning" />
  const apply = (): void => { if (name.trim()) { updateGroup(group.id, { name: name.trim() }); setDirty(false) } }
  return <Win95Dialog title={`${group.name} Properties`} onClose={onClose} width={365} height={285}>
    <PropertyTabs tab="general" setTab={() => undefined} labels={[{ id: 'general', label: '&General' }]} />
    <div className="win95-property-page">
      <div className="win95-properties-heading"><img src={getWin95IconSrc('folder', 'large')} alt="" /><Win95BitmapText text={group.name} bold /></div>
      <FormRow label="&Name:"><Win95TextInput value={name} onChange={(event) => { setName(event.target.value); setDirty(true) }} /></FormRow>
      <Win95BitmapText text={`Contains ${group.items.length} object${group.items.length === 1 ? '' : 's'}.`} />
    </div>
    <form onSubmit={(event) => { event.preventDefault(); apply(); onClose() }}><DialogButtons onCancel={onClose} apply={apply} applyDisabled={!dirty} /></form>
  </Win95Dialog>
}

function NewUrlDialog({ onClose }: { onClose: () => void }): JSX.Element {
  const data = useUIStore((state) => state.dialogData)
  const groups = useProgramStore((state) => state.groups)
  const addItem = useProgramStore((state) => state.addItem)
  const openGroup = useWin95WindowStore((state) => state.openGroup)
  const [groupId, setGroupId] = useState(data.groupId ?? groups[0]?.id ?? '')
  const [name, setName] = useState('New Internet Shortcut')
  const [url, setUrl] = useState('https://')
  const submit = (event: FormEvent): void => {
    event.preventDefault(); if (!groupId || !name.trim() || !/^https?:\/\//i.test(url)) return
    addItem(groupId, { name: name.trim(), path: url.trim(), icon: 'url', workingDir: '' }); openGroup(groupId); onClose()
  }
  return <Win95Dialog title="New Internet Shortcut" onClose={onClose} width={390} height={185}><form onSubmit={submit}>
    <FormRow label="&Name:"><Win95TextInput value={name} onChange={(event) => setName(event.target.value)} /></FormRow>
    <FormRow label="Internet &address:"><Win95TextInput value={url} onChange={(event) => setUrl(event.target.value)} /></FormRow>
    <FormRow label="Program &group:"><Win95Select value={groupId} onChange={(event) => setGroupId(event.target.value)}>{groups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}</Win95Select></FormRow>
    <DialogButtons onCancel={onClose} />
  </form></Win95Dialog>
}

const RUN_HISTORY: string[] = []
function RunDialog({ onClose }: { onClose: () => void }): JSX.Element {
  const [command, setCommand] = useState('')
  const [historyOpen, setHistoryOpen] = useState(false)
  const [error, setError] = useState('')
  const run = async (event?: FormEvent): Promise<void> => {
    event?.preventDefault(); const value = command.trim(); if (!value) return
    const item: ProgramItem = { id: 'win95-run', name: value, path: value, icon: 'run', workingDir: '' }
    const result = await window.electronAPI.program.launch(item)
    if (result.success) { if (!RUN_HISTORY.includes(value)) RUN_HISTORY.unshift(value); onClose() }
    else setError(result.error ?? `Cannot find '${value}'.`)
  }
  const browse = async (): Promise<void> => { const path = await window.electronAPI.file.selectExecutable(); if (path) { setCommand(path); setError('') } }
  return <Win95Dialog title="Run" onClose={onClose} width={WIN95_METRICS.runDialogWidth} height={WIN95_METRICS.runDialogHeight}
    contextHelp="Type a launcher command or path in Open. Browse selects an executable; successful commands are retained for this launcher session.">
    <form onSubmit={(event) => void run(event)}>
      <div className="win95-run-intro"><img src={getWin95IconSrc('run', 'large')} alt="" /><Win95BitmapText text="Type the name of a program, folder, document, or Internet resource, and Windows will open it for you." wrap maxWidth={265} /></div>
      <label className="win95-run-open"><Win95BitmapText text="&Open:" /><span className="win95-combo"><Win95TextInput value={command} onChange={(event) => { setCommand(event.target.value); setError('') }} /><button type="button" tabIndex={-1} aria-label="Open history" onClick={() => setHistoryOpen((open) => !open)}><Win95Glyph name="combo-down" /></button>{historyOpen && <span className="win95-combo-list">{RUN_HISTORY.length ? RUN_HISTORY.map((entry) => <button type="button" key={entry} onClick={() => { setCommand(entry); setHistoryOpen(false) }}><Win95BitmapText text={entry} /></button>) : <Win95BitmapText text="(Empty)" disabled />}</span>}</span></label>
      {error && <div className="win95-run-error"><Win95BitmapText text={error} color="#800000" maxWidth={315} /></div>}
      <div className="win95-dialog-buttons win95-run-buttons"><Win95Button type="submit" label="&OK" defaultButton /><Win95Button type="button" label="&Cancel" onClick={onClose} /><Win95Button type="button" label="&Browse..." onClick={() => void browse()} /></div>
    </form>
  </Win95Dialog>
}

function HelpDialog({ onClose }: { onClose: () => void }): JSX.Element {
  return <Win95Dialog title="Gosh 95 Help" onClose={onClose} width={430} height={245}>
    <div className="win95-help-layout"><div className="win95-help-topics"><Win95BitmapText text="Contents" bold /><button type="button"><Win95BitmapText text="Starting a program" /></button><button type="button"><Win95BitmapText text="Organizing programs" /></button><button type="button"><Win95BitmapText text="Using Find and Run" /></button></div>
      <div className="win95-help-copy"><h2><Win95BitmapText text="Starting a program" bold /></h2><Win95BitmapText text="Click Start, point to Programs, point to a program group, and then click the program you want to start." wrap maxWidth={230} /><br /><Win95BitmapText text="You can also open My Computer and double-click a saved application." wrap maxWidth={230} /></div></div>
    <div className="win95-dialog-buttons"><Win95Button label="OK" defaultButton onClick={onClose} /></div>
  </Win95Dialog>
}

function AboutDialog({ onClose }: { onClose: () => void }): JSX.Element {
  const [version, setVersion] = useState('')
  useEffect(() => { void window.electronAPI.system.getVersion().then(setVersion) }, [])
  return <Win95Dialog title="About Gosh 95" onClose={onClose} width={380} height={205}>
    <div className="win95-about"><img src={getWin95IconSrc('windows-logo', 'large')} alt="" /><div><Win95BitmapText text="Gosh 95" bold /><br /><Win95BitmapText text="Windows 95 RTM-style application launcher" /><br /><Win95BitmapText text={`Version ${version}`} /></div></div>
    <hr /><Win95BitmapText text="This launcher provides a period-style interface for starting saved applications. It does not emulate Microsoft Windows." wrap maxWidth={330} />
    <div className="win95-dialog-buttons"><Win95Button label="OK" defaultButton onClick={onClose} /></div>
  </Win95Dialog>
}

function ConfirmDialog({ onClose }: { onClose: () => void }): JSX.Element {
  const options = useUIStore((state) => state.dialogData.confirmOptions)
  if (!options) return <></>
  const cancel = (): void => { options.onCancel?.(); onClose() }
  return <Win95Dialog title={options.title} onClose={cancel} width={355} height={145}>
    <div className="win95-message"><img src={getWin95IconSrc('question', 'large')} alt="" /><Win95BitmapText text={options.message} wrap maxWidth={275} /></div>
    <div className="win95-dialog-buttons"><Win95Button label="&Yes" onClick={() => { options.onConfirm(); onClose() }} /><Win95Button label="&No" defaultButton data-initial-focus onClick={cancel} /></div>
  </Win95Dialog>
}

function MessageDialog({ title, message, onClose, symbol = 'information' }: { title: string; message: string; onClose: () => void; symbol?: 'information' | 'warning' | 'critical' }): JSX.Element {
  return <Win95Dialog title={title} onClose={onClose} width={355} height={145}><div className="win95-message"><img src={getWin95IconSrc(symbol, 'large')} alt="" /><Win95BitmapText text={message} wrap maxWidth={275} /></div><div className="win95-dialog-buttons"><Win95Button label="OK" defaultButton onClick={onClose} /></div></Win95Dialog>
}

type ShutdownChoice = 'quit' | 'restart' | 'win31' | 'msdos'
function ShutDownDialog({ onClose }: { onClose: () => void }): JSX.Element {
  const settings = useProgramStore((state) => state.settings)
  const updateSettings = useProgramStore((state) => state.updateSettings)
  const [choice, setChoice] = useState<ShutdownChoice>('quit')
  const [helpOpen, setHelpOpen] = useState(false)
  const submit = (event: FormEvent): void => {
    event.preventDefault()
    if (choice === 'quit') void window.electronAPI.window.quit()
    else if (choice === 'restart') void window.electronAPI.window.recreateForShell(settings.shell)
    else if (choice === 'win31') {
      const next = { ...settings, shell: 'win31' as const }
      void applyShellSettingsTransaction(settings, next, {
        persist: (value) => window.electronAPI.store.set('settings', value),
        updateRenderer: updateSettings,
        recreate: (shell) => window.electronAPI.window.recreateForShell(shell)
      })
    }
  }
  return <>
    <Win95Dialog title="Shut Down Windows" onClose={onClose} width={WIN95_METRICS.shutdownDialogWidth} height={WIN95_METRICS.shutdownDialogHeight}>
      <form onSubmit={submit}>
        <div className="win95-shutdown"><img src={getWin95IconSrc('shutdown', 'large')} alt="" /><div><Win95BitmapText text="What do you want the computer to do?" />
          <Win95Radio label="&Shut down the launcher" name="shutdown" value="quit" checked={choice === 'quit'} onChange={() => setChoice('quit')} />
          <Win95Radio label="&Restart the launcher" name="shutdown" value="restart" checked={choice === 'restart'} onChange={() => setChoice('restart')} />
          <Win95Radio label="Restart in Windows for &Workgroups 3.11" name="shutdown" value="win31" checked={choice === 'win31'} onChange={() => setChoice('win31')} />
          <Win95Radio label="Restart the computer in &MS-DOS mode" name="shutdown" value="msdos" checked={false} disabled />
        </div></div>
        <div className="win95-dialog-buttons win95-shutdown-buttons"><Win95Button type="submit" label="&Yes" /><Win95Button type="button" label="&No" defaultButton data-initial-focus onClick={onClose} /><Win95Button type="button" label="&Help" onClick={() => setHelpOpen(true)} /></div>
      </form>
    </Win95Dialog>
    {helpOpen && <MessageDialog title="Shut Down Help" message="Shut Down affects only Gosh Retro Launcher. Restart can recreate this launcher in Windows 95 or switch it to Windows for Workgroups 3.11. Computer and MS-DOS operations remain unavailable." onClose={() => setHelpOpen(false)} />}
  </>
}
