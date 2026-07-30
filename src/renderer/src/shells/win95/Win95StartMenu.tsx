import { useCallback, useEffect, useMemo, useRef, useState, type JSX } from 'react'
import type { ProgramItem } from '@shared/types'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { getWin95IconSrc } from './iconCatalog'
import { useWin95Scale } from './Win95ScaleContext'
import { useWin95InputHandler, useWin95MenuScope, useWin95PointerHandler } from './Win95InputController'
import { Win95BitmapText } from './bitmapText'
import { Win95Glyph } from './Win95Primitives'
import { mnemonicIndex, reduceMenuNavigation, type MenuNavigationKey } from './menuState'
import { menuColumnLayout } from './shellInput'
import { WIN95_METRICS } from './tokens'

interface Win95StartMenuProps { isOpen: boolean; onClose: () => void }
type TopId = 'programs' | 'documents' | 'settings' | 'find' | 'help' | 'run' | 'shutdown'

const TOP_ITEMS: Array<{ id: TopId; label: string; icon: string; child?: boolean; separatorBefore?: boolean }> = [
  { id: 'programs', label: '&Programs', icon: 'programs', child: true },
  { id: 'documents', label: '&Documents', icon: 'documents', child: true },
  { id: 'settings', label: '&Settings', icon: 'settings', child: true },
  { id: 'find', label: '&Find', icon: 'find', child: true },
  { id: 'help', label: '&Help', icon: 'help' },
  { id: 'run', label: '&Run...', icon: 'run' },
  { id: 'shutdown', label: 'Sh&ut Down...', icon: 'shutdown', separatorBefore: true }
]

const FIND_ITEMS = [
  { id: 'programs', label: '&Files or Folders...', icon: 'find' },
  { id: 'computer', label: '&Computer...', icon: 'my-computer' },
  { id: 'internet', label: 'On the &Internet...', icon: 'url' }
]

const SETTINGS_ITEMS = [
  { id: 'control', label: '&Control Panel', icon: 'control-panel' },
  { id: 'printers', label: '&Printers', icon: 'printers' },
  { id: 'taskbar', label: '&Taskbar...', icon: 'taskbar' },
  { id: 'tools', label: '&Launcher Tools...', icon: 'settings', separatorBefore: true }
]

function MenuLabel({ label, disabled = false, selected = false }: { label: string; disabled?: boolean; selected?: boolean }): JSX.Element {
  return <Win95BitmapText text={label} disabled={disabled} color={selected ? '#ffffff' : '#000000'} />
}

export function Win95StartMenu({ isOpen, onClose }: Win95StartMenuProps): JSX.Element | null {
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const openDialog = useUIStore((state) => state.openDialog)
  const openQuickSearch = useUIStore((state) => state.openQuickSearch)
  const { scale, logicalViewport } = useWin95Scale()
  const menuRef = useRef<HTMLDivElement>(null)
  const delayRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const [openTop, setOpenTop] = useState<TopId | null>(null)
  const [openGroup, setOpenGroup] = useState<string | null>(null)
  const [level, setLevel] = useState(0)
  const [indices, setIndices] = useState([-1, 0, 0])

  const clearDelay = (): void => { if (delayRef.current) { clearTimeout(delayRef.current); delayRef.current = null } }
  const delayedOpen = useCallback((top: TopId | null, groupId: string | null = null) => {
    clearDelay()
    delayRef.current = setTimeout(() => {
      setOpenTop(top); setOpenGroup(groupId); delayRef.current = null
    }, WIN95_METRICS.submenuDelayMs)
  }, [])

  useEffect(() => () => clearDelay(), [])
  useEffect(() => {
    if (isOpen) { setOpenTop(null); setOpenGroup(null); setLevel(0); setIndices([-1, 0, 0]) }
    else clearDelay()
  }, [isOpen])

  useWin95MenuScope('start-menu', isOpen)
  useWin95PointerHandler('pointerdown', 'start-menu-outside', (event) => {
    if (!isOpen) return false
    const target = event.target as HTMLElement
    if (target.closest('.win95-start-button') || menuRef.current?.contains(target)) return false
    onClose()
    return true
  }, isOpen)

  const launch = useCallback(async (item: ProgramItem) => {
    const result = await window.electronAPI.program.launch(item)
    if (!result.success) openDialog('unavailable', { title: item.name, message: result.error ?? `Windows cannot find '${item.path}'.` })
    else if (settings.minimizeOnUse) void window.electronAPI.window.minimize()
    onClose()
  }, [onClose, openDialog, settings.minimizeOnUse])

  const activateTop = useCallback((id: TopId): void => {
    if (id === 'programs' || id === 'documents' || id === 'settings') { setOpenTop(id); setLevel(1); setIndices((old) => [old[0], 0, 0]); return }
    if (id === 'find') { setOpenTop('find'); setLevel(1); setIndices((old) => [old[0], 0, 0]) }
    else if (id === 'help') { openDialog('help'); onClose() }
    else if (id === 'run') { openDialog('run'); onClose() }
    else if (id === 'shutdown') { openDialog('exitWindows'); onClose() }
  }, [onClose, openDialog, openQuickSearch])

  const activateFind = (id: string): void => {
    if (id === 'programs') openQuickSearch()
    else openDialog('unavailable', {
      title: FIND_ITEMS.find((item) => item.id === id)?.label.replace('&', '') ?? 'Find',
      message: 'This search target is not available in the application launcher.'
    })
    onClose()
  }

  const activateSettings = (id: string): void => {
    if (id === 'tools') void window.electronAPI.app.openLauncherTools()
    else openDialog('unavailable', {
      title: SETTINGS_ITEMS.find((item) => item.id === id)?.label.replace('&','') ?? 'Settings',
      message: 'This Windows system feature is not available in the application launcher.'
    })
    onClose()
  }

  const levelItems = useMemo(() => {
    if (level === 0) return TOP_ITEMS
    if (level === 1 && openTop === 'programs') return groups
    if (level === 1 && openTop === 'settings') return SETTINGS_ITEMS
    if (level === 1 && openTop === 'find') return FIND_ITEMS
    if (level === 1 && openTop === 'documents') return []
    if (level === 2 && openGroup) return groups.find((group) => group.id === openGroup)?.items ?? []
    return []
  }, [groups, level, openGroup, openTop])

  useWin95InputHandler('menu', 'start-menu', (event) => {
    if (!isOpen) return false
    const keys = ['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Home','End','Enter','Escape']
    if (!keys.includes(event.key)) {
      if (event.key.length !== 1) return false
      const labels = levelItems.map((item) => 'label' in item ? item.label : `&${item.name}`)
      const match = mnemonicIndex(labels, event.key)
      if (match < 0) return false
      setIndices((old) => { const next = [...old]; next[level] = match; return next })
      const matched = levelItems[match]
      if (matched) {
        if (level === 0 && 'label' in matched) activateTop(matched.id as TopId)
        else if (level === 1 && openTop === 'settings' && 'label' in matched) activateSettings(matched.id)
        else if (level === 1 && openTop === 'find' && 'label' in matched) activateFind(matched.id)
        else if (level === 1 && openTop === 'programs' && 'name' in matched) { setOpenGroup(matched.id); setLevel(2) }
        else if (level === 2 && 'path' in matched) void launch(matched)
      }
      return true
    }
    const selected = levelItems[indices[level]]
    const hasChild = level === 0
      ? !!(selected && 'child' in selected && selected.child)
      : level === 1 && openTop === 'programs' && !!selected
    const result = reduceMenuNavigation({ level, indices }, event.key as MenuNavigationKey,
      [TOP_ITEMS.length, level === 1 ? levelItems.length : (openTop === 'programs' ? groups.length : openTop === 'find' ? FIND_ITEMS.length : SETTINGS_ITEMS.length), level === 2 ? levelItems.length : 0], hasChild)
    setIndices(result.indices)
    if (result.action === 'close-all') { onClose(); return true }
    if (result.action === 'close-level') {
      setLevel(result.level)
      if (result.level < 2) setOpenGroup(null)
      if (result.level === 0) setOpenTop(null)
      return true
    }
    if (result.action === 'open-child') {
      if (level === 0 && selected && 'id' in selected) { setOpenTop(selected.id as TopId); setLevel(1) }
      else if (level === 1 && openTop === 'programs' && selected && 'name' in selected) { setOpenGroup(selected.id); setLevel(2) }
      return true
    }
    if (result.action === 'activate' && selected) {
      if (level === 0 && 'label' in selected) activateTop(selected.id as TopId)
      else if (level === 1 && openTop === 'settings' && 'label' in selected) activateSettings(selected.id)
      else if (level === 1 && openTop === 'find' && 'label' in selected) activateFind(selected.id)
      else if (level === 2 && 'path' in selected) void launch(selected)
    }
    return true
  }, isOpen)

  if (!isOpen) return null
  const programRows = Math.max(1, Math.floor((WIN95_METRICS.startMenuHeight - 4) / WIN95_METRICS.startSubItemHeight))
  const programColumns = menuColumnLayout(groups.map(() => WIN95_METRICS.startSubItemHeight), programRows * WIN95_METRICS.startSubItemHeight)
  const levelOneTop = openTop ? Math.max(-2, TOP_ITEMS.findIndex((item) => item.id === openTop) * WIN95_METRICS.startTopItemHeight - 2) : -2
  const openGroupIndex = Math.max(0, groups.findIndex((group) => group.id === openGroup))
  const openGroupRow = openGroupIndex % programRows
  const levelOneWidth = Math.max(1, programColumns.length) * 164
  const naturalThirdLeft = WIN95_METRICS.startMenuWidth - 1 + levelOneWidth - 1
  const thirdLeft = naturalThirdLeft + 164 > logicalViewport.width
    ? WIN95_METRICS.startMenuWidth - 1 - 164 + 1
    : naturalThirdLeft
  const thirdCount = groups.find((group) => group.id === openGroup)?.items.length ?? 0
  const thirdHeight = Math.max(1, thirdCount) * WIN95_METRICS.startSubItemHeight + 4
  const mainTop = logicalViewport.height - WIN95_METRICS.taskbarHeight - WIN95_METRICS.startMenuHeight
  const thirdTop = Math.max(-mainTop, Math.min(
    levelOneTop + openGroupRow * WIN95_METRICS.startSubItemHeight - 2,
    logicalViewport.height - WIN95_METRICS.taskbarHeight - mainTop - thirdHeight
  ))

  return (
    <div ref={menuRef} className="win95-start-menu" role="menu" aria-label="Start menu">
      <div className="win95-start-strip"><Win95BitmapText text="Windows 95" bold color="#ffffff" fontPx={18} lineHeight={19} vertical /></div>
      <div className="win95-start-commands">
        {TOP_ITEMS.map((item, index) => (
          <div key={item.id}>
            {item.separatorBefore && <div className="win95-menu-separator" />}
            <button type="button" className={`win95-start-command ${indices[0] === index ? 'selected' : ''}`}
              onPointerEnter={() => { setIndices((old) => [index, old[1], old[2]]); setLevel(0); delayedOpen(item.child ? item.id : null) }}
              onPointerUp={() => { if (document.documentElement.dataset.win95StartTracking) activateTop(item.id) }}
              onClick={() => activateTop(item.id)}>
              <img src={getWin95IconSrc(item.icon, 'large', scale)} alt="" />
              <span><MenuLabel label={item.label} selected={indices[0] === index} /></span>{item.child && <i><Win95Glyph name="menu-right" color={indices[0] === index ? '#ffffff' : '#000000'} /></i>}
            </button>
          </div>
        ))}
      </div>

      {openTop === 'programs' && (
        <div className={`win95-start-submenu start-level-1 ${programColumns.length > 1 ? 'multi-column' : ''}`}
          style={programColumns.length > 1 ? {
            display: 'grid', gridAutoFlow: 'column', gridTemplateRows: `repeat(${programRows}, ${WIN95_METRICS.startSubItemHeight}px)`,
            gridAutoColumns: '164px', width: programColumns.length * 164, top: levelOneTop
          } : { top: levelOneTop }}
          role="menu" aria-label="Programs">
          {groups.length === 0 && <button type="button" disabled className="win95-sub-command"><span>(Empty)</span></button>}
          {groups.map((group, index) => (
            <button type="button" key={group.id} className={`win95-sub-command ${level === 1 && indices[1] === index ? 'selected' : ''}`}
              onPointerEnter={() => { setLevel(1); setIndices((old) => [old[0], index, old[2]]); delayedOpen('programs', group.id) }}
              onPointerUp={() => { if (document.documentElement.dataset.win95StartTracking) { setOpenGroup(group.id); setLevel(2) } }}
              onClick={() => { setOpenGroup(group.id); setLevel(2) }}>
              <img src={getWin95IconSrc('programs', 'small', scale)} alt="" /><Win95BitmapText text={group.name} color={level === 1 && indices[1] === index ? '#ffffff' : '#000000'} /><i><Win95Glyph name="menu-right" color={level === 1 && indices[1] === index ? '#ffffff' : '#000000'} /></i>
            </button>
          ))}
        </div>
      )}
      {openTop === 'documents' && <div className="win95-start-submenu start-level-1" style={{ top: levelOneTop }}><button type="button" disabled className="win95-sub-command"><span>(Empty)</span></button></div>}
      {openTop === 'find' && (
        <div className="win95-start-submenu start-level-1" style={{ top: levelOneTop }} role="menu" aria-label="Find">
          {FIND_ITEMS.map((item, index) => <button type="button" key={item.id}
            className={`win95-sub-command ${level === 1 && indices[1] === index ? 'selected' : ''}`}
            onPointerEnter={() => { clearDelay(); setOpenGroup(null); setLevel(1); setIndices((old) => [old[0], index, old[2]]) }}
            onPointerUp={() => { if (document.documentElement.dataset.win95StartTracking) activateFind(item.id) }}
            onClick={() => activateFind(item.id)}>
            <img src={getWin95IconSrc(item.icon, 'small', scale)} alt="" /><span><MenuLabel label={item.label} selected={level === 1 && indices[1] === index} /></span>
          </button>)}
        </div>
      )}
      {openTop === 'settings' && (
        <div className="win95-start-submenu start-level-1" style={{ top: levelOneTop }} role="menu" aria-label="Settings">
          {SETTINGS_ITEMS.map((item, index) => <div key={item.id}>
            {item.separatorBefore && <div className="win95-menu-separator" />}
            <button type="button" className={`win95-sub-command ${level === 1 && indices[1] === index ? 'selected' : ''}`}
              onPointerEnter={() => { clearDelay(); setOpenGroup(null); setLevel(1); setIndices((old) => [old[0], index, old[2]]) }}
              onPointerUp={() => { if (document.documentElement.dataset.win95StartTracking) activateSettings(item.id) }}
              onClick={() => activateSettings(item.id)}>
              <img src={getWin95IconSrc(item.icon, 'small', scale)} alt="" /><span><MenuLabel label={item.label} selected={level === 1 && indices[1] === index} /></span>
            </button>
          </div>)}
        </div>
      )}
      {openTop === 'programs' && openGroup && (
        <div className="win95-start-submenu start-level-2" style={{ left: thirdLeft, top: thirdTop }} role="menu" aria-label="Program group">
          {(groups.find((group) => group.id === openGroup)?.items ?? []).map((item, index) => (
            <button type="button" key={item.id} className={`win95-sub-command ${level === 2 && indices[2] === index ? 'selected' : ''}`}
              onPointerEnter={() => { setLevel(2); setIndices((old) => [old[0], old[1], index]) }}
              onPointerUp={() => { if (document.documentElement.dataset.win95StartTracking) void launch(item) }}
              onClick={() => void launch(item)}>
              <img src={getWin95IconSrc(item.icon, 'small', scale)} alt="" /><Win95BitmapText text={item.name} color={level === 2 && indices[2] === index ? '#ffffff' : '#000000'} />
            </button>
          ))}
          {(groups.find((group) => group.id === openGroup)?.items.length ?? 0) === 0 && <button type="button" disabled className="win95-sub-command"><span>(Empty)</span></button>}
        </div>
      )}
    </div>
  )
}
