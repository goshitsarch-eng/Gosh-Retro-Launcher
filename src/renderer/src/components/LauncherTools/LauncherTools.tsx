import { useEffect, useMemo, useState, type JSX } from 'react'
import type { BackupInfo, ProgramRunMode, ShellType, Win31ScalePreference } from '@shared/types'
import { useProgramStore } from '@/store/programStore'

export function LauncherTools(): JSX.Element {
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const profiles = useProgramStore((state) => state.workspaceProfiles)
  const loadData = useProgramStore((state) => state.loadData)
  const updateSettings = useProgramStore((state) => state.updateSettings)
  const importGroup = useProgramStore((state) => state.importGroup)
  const saveGroups = useProgramStore((state) => state.saveGroups)
  const addItem = useProgramStore((state) => state.addItem)
  const updateItem = useProgramStore((state) => state.updateItem)
  const saveWorkspaceProfile = useProgramStore((state) => state.saveWorkspaceProfile)
  const applyWorkspaceProfile = useProgramStore((state) => state.applyWorkspaceProfile)
  const deleteWorkspaceProfile = useProgramStore((state) => state.deleteWorkspaceProfile)
  const renameWorkspaceProfile = useProgramStore((state) => state.renameWorkspaceProfile)

  const [shell, setShell] = useState<ShellType>(settings.shell)
  const [scale, setScale] = useState<Win31ScalePreference>(settings.win31Scale)
  const [desktopMode, setDesktopMode] = useState(settings.win31DesktopMode)
  const [sound, setSound] = useState(settings.soundEnabled)
  const [tray, setTray] = useState(settings.trayOnClose)
  const [selectedGroup, setSelectedGroup] = useState('')
  const [profileName, setProfileName] = useState('')
  const [selectedProfile, setSelectedProfile] = useState('')
  const [renameProfile, setRenameProfile] = useState('')
  const [urlName, setUrlName] = useState('')
  const [urlValue, setUrlValue] = useState('https://')
  const [selectedItemKey, setSelectedItemKey] = useState('')
  const [backups, setBackups] = useState<BackupInfo[]>([])
  const [status, setStatus] = useState('Ready.')

  useEffect(() => {
    setShell(settings.shell)
    setScale(settings.win31Scale)
    setDesktopMode(settings.win31DesktopMode)
    setSound(settings.soundEnabled)
    setTray(settings.trayOnClose)
  }, [settings])

  useEffect(() => {
    if (!selectedGroup && groups[0]) setSelectedGroup(groups[0].id)
    if (selectedGroup && !groups.some((group) => group.id === selectedGroup)) setSelectedGroup(groups[0]?.id ?? '')
  }, [groups, selectedGroup])

  useEffect(() => {
    if (!selectedProfile && profiles[0]) {
      setSelectedProfile(profiles[0].id)
      setRenameProfile(profiles[0].name)
    }
  }, [profiles, selectedProfile])

  const selectedProfileEntry = profiles.find((profile) => profile.id === selectedProfile)
  const selectedItem = useMemo(() => {
    const [groupId, itemId] = selectedItemKey.split(':')
    const group = groups.find((entry) => entry.id === groupId)
    return group && itemId ? { group, item: group.items.find((entry) => entry.id === itemId) } : null
  }, [groups, selectedItemKey])

  const refreshBackups = async (): Promise<void> => setBackups(await window.electronAPI.store.listBackups())
  useEffect(() => { void refreshBackups() }, [])

  const applyAppearance = async (): Promise<void> => {
    const next = { ...settings, shell, win31Scale: scale, win31DesktopMode: desktopMode, soundEnabled: sound, trayOnClose: tray }
    updateSettings(next)
    await window.electronAPI.store.set('settings', next)
    if (shell !== settings.shell) await window.electronAPI.window.recreateForShell(shell)
    setStatus('Appearance settings applied.')
  }

  const importGrp = async (): Promise<void> => {
    const result = await window.electronAPI.file.importGrp()
    if (!result.success || !result.group) {
      if (result.error !== 'Canceled') setStatus(result.error ?? 'Could not import the group.')
      return
    }
    const enriched = {
      ...result.group,
      items: await Promise.all(result.group.items.map(async (item) => {
        try {
          const info = await window.electronAPI.app.getInfo(item.path)
          return {
            ...item,
            icon: info.icon ?? item.icon,
            win31Icon: info.win31Icon ?? item.win31Icon,
            workingDir: item.workingDir || info.workingDir || ''
          }
        } catch {
          return item
        }
      }))
    }
    importGroup(enriched)
    await saveGroups()
    setSelectedGroup(enriched.id)
    setStatus(`Imported “${enriched.name}” from .GRP.`)
  }

  const exportGrp = async (): Promise<void> => {
    const group = groups.find((entry) => entry.id === selectedGroup)
    if (!group) return
    const result = await window.electronAPI.file.exportGrp(group)
    if (result.success) setStatus(`Exported “${group.name}” as a Windows 3.x .GRP file.`)
    else if (result.error !== 'Canceled') setStatus(result.error ?? 'Could not export the group.')
  }

  const addUrl = (): void => {
    if (!selectedGroup || !urlName.trim() || !/^https?:\/\//i.test(urlValue)) return
    addItem(selectedGroup, {
      name: urlName.trim(), path: urlValue.trim(), workingDir: '', icon: 'network', win31Icon: 'network'
    })
    setUrlName('')
    setStatus('URL launcher added.')
  }

  return (
    <main className="launcher-tools">
      <header>
        <h1>Launcher Tools</h1>
        <p>Modern launcher features are kept outside the Windows 3.11 Program Manager surface.</p>
      </header>

      <section>
        <h2>Shell and appearance</h2>
        <div className="tools-grid">
          <label>Shell
            <select value={shell} onChange={(event) => setShell(event.target.value as ShellType)}>
              <option value="win31">Windows for Workgroups 3.11</option>
              <option value="win95">Windows 95</option>
            </select>
          </label>
          <label>WfW scale
            <select value={scale} onChange={(event) => setScale(event.target.value === 'auto' ? 'auto' : Number(event.target.value) as 1 | 2 | 3 | 4)}>
              <option value="auto">Auto</option>{[1, 2, 3, 4].map((value) => <option value={value} key={value}>{value}×</option>)}
            </select>
          </label>
        </div>
        <div className="tools-checks">
          <label><input type="checkbox" checked={desktopMode} onChange={(event) => setDesktopMode(event.target.checked)} /> WfW gray desktop mode</label>
          <label><input type="checkbox" checked={sound} onChange={(event) => setSound(event.target.checked)} /> Sound effects</label>
          <label><input type="checkbox" checked={tray} onChange={(event) => setTray(event.target.checked)} /> Minimize to tray on close</label>
        </div>
        <button onClick={() => void applyAppearance()}>Apply</button>
      </section>

      <section>
        <h2>Windows 3.x groups</h2>
        <div className="tools-row">
          <select value={selectedGroup} onChange={(event) => setSelectedGroup(event.target.value)}>
            {groups.map((group) => <option value={group.id} key={group.id}>{group.name}</option>)}
          </select>
          <button onClick={() => void importGrp()}>Import .GRP...</button>
          <button disabled={!selectedGroup} onClick={() => void exportGrp()}>Export .GRP...</button>
          <button onClick={() => void window.electronAPI.store.importData().then(async (result) => {
            if (result.success) { await loadData(); setStatus('Launcher backup imported.') }
            else if (result.error !== 'Canceled') setStatus(result.error ?? 'Import failed.')
          })}>Import JSON...</button>
          <button onClick={() => void window.electronAPI.store.exportData().then((saved) => saved && setStatus('Launcher backup exported.'))}>Export JSON...</button>
        </div>
      </section>

      <section>
        <h2>URL launcher</h2>
        <div className="tools-grid tools-grid-three">
          <label>Name<input value={urlName} onChange={(event) => setUrlName(event.target.value)} /></label>
          <label>URL<input value={urlValue} onChange={(event) => setUrlValue(event.target.value)} /></label>
          <label>Group<select value={selectedGroup} onChange={(event) => setSelectedGroup(event.target.value)}>
            {groups.map((group) => <option value={group.id} key={group.id}>{group.name}</option>)}
          </select></label>
        </div>
        <button disabled={!groups.length || !urlName.trim()} onClick={addUrl}>Add URL</button>
      </section>

      <section>
        <h2>Launch profile and batch metadata</h2>
        <select value={selectedItemKey} onChange={(event) => setSelectedItemKey(event.target.value)}>
          <option value="">Select a program item...</option>
          {groups.flatMap((group) => group.items.map((item) => (
            <option value={`${group.id}:${item.id}`} key={`${group.id}:${item.id}`}>{group.name} — {item.name}</option>
          )))}
        </select>
        {selectedItem?.item && (
          <LaunchProfileEditor key={selectedItem.item.id} item={selectedItem.item} onSave={(updates) => {
            updateItem(selectedItem.group.id, selectedItem.item!.id, updates)
            setStatus('Launch profile saved.')
          }} />
        )}
      </section>

      <section>
        <h2>Workspace profiles</h2>
        <div className="tools-row">
          <input placeholder="New profile name" value={profileName} onChange={(event) => setProfileName(event.target.value)} />
          <button onClick={() => {
            const id = saveWorkspaceProfile(profileName)
            setProfileName(''); setSelectedProfile(id); setStatus('Workspace profile saved.')
          }}>Save current workspace</button>
        </div>
        <div className="tools-row">
          <select value={selectedProfile} onChange={(event) => {
            setSelectedProfile(event.target.value)
            setRenameProfile(profiles.find((profile) => profile.id === event.target.value)?.name ?? '')
          }}>
            <option value="">Select a profile...</option>
            {profiles.map((profile) => <option value={profile.id} key={profile.id}>{profile.name}</option>)}
          </select>
          <button disabled={!selectedProfile} onClick={() => { applyWorkspaceProfile(selectedProfile); setStatus('Workspace profile applied.') }}>Apply</button>
          <input value={renameProfile} onChange={(event) => setRenameProfile(event.target.value)} disabled={!selectedProfile} />
          <button disabled={!selectedProfile || !renameProfile.trim()} onClick={() => renameWorkspaceProfile(selectedProfile, renameProfile)}>Rename</button>
          <button disabled={!selectedProfile} onClick={() => { deleteWorkspaceProfile(selectedProfile); setSelectedProfile(''); setRenameProfile('') }}>Delete</button>
        </div>
        {selectedProfileEntry && <small>{selectedProfileEntry.groups.length} groups · updated {new Date(selectedProfileEntry.updatedAt).toLocaleString()}</small>}
      </section>

      <section>
        <h2>Backup and recovery</h2>
        <div className="tools-row">
          <button onClick={() => void window.electronAPI.store.createBackup('manual').then(async () => { await refreshBackups(); setStatus('Restore point created.') })}>Create restore point</button>
          <button onClick={() => void refreshBackups()}>Refresh</button>
        </div>
        <div className="tools-backups">
          {backups.map((backup) => (
            <div key={backup.id}>
              <span>{new Date(backup.createdAt).toLocaleString()} — {backup.reason.replace(/-/g, ' ')}</span>
              <button onClick={() => void window.electronAPI.store.restoreBackup(backup.id).then(async (result) => {
                if (result.success) { await loadData(); setStatus('Backup restored.') }
                else setStatus(result.error ?? 'Restore failed.')
              })}>Restore</button>
            </div>
          ))}
          {!backups.length && <p>No restore points yet.</p>}
        </div>
      </section>

      <footer role="status">{status}</footer>
    </main>
  )
}

function LaunchProfileEditor({ item, onSave }: {
  item: { arguments?: string; workingDir: string; environment?: string; runMode?: ProgramRunMode; launchGroup?: number }
  onSave: (updates: { arguments: string; workingDir: string; environment: string; runMode: ProgramRunMode; launchGroup: number }) => void
}): JSX.Element {
  const [args, setArgs] = useState(item.arguments ?? '')
  const [workingDir, setWorkingDir] = useState(item.workingDir)
  const [environment, setEnvironment] = useState(item.environment ?? '')
  const [runMode, setRunMode] = useState<ProgramRunMode>(item.runMode ?? 'normal')
  const [launchGroup, setLaunchGroup] = useState(item.launchGroup ?? 0)
  return (
    <div className="tools-profile-editor">
      <label>Arguments<input value={args} onChange={(event) => setArgs(event.target.value)} /></label>
      <label>Working directory<input value={workingDir} onChange={(event) => setWorkingDir(event.target.value)} /></label>
      <label>Environment<textarea rows={3} value={environment} onChange={(event) => setEnvironment(event.target.value)} placeholder="KEY=VALUE" /></label>
      <label>Run mode<select value={runMode} onChange={(event) => setRunMode(event.target.value as ProgramRunMode)}>
        <option value="normal">Normal</option><option value="minimized">Minimized</option><option value="maximized">Maximized</option>
      </select></label>
      <label>Batch group<input type="number" min={0} max={99} value={launchGroup} onChange={(event) => setLaunchGroup(Number(event.target.value))} /></label>
      <button onClick={() => onSave({ arguments: args, workingDir, environment, runMode, launchGroup })}>Save launch profile</button>
    </div>
  )
}
