import { useEffect, useMemo, useRef, useState, type JSX } from 'react'
import type { ProgramGroup } from '@shared/types'
import type { Win31Command, Win31CommandState } from './commands'

export interface Win31MenuItemModel {
  command?: Win31Command
  label?: string
  separator?: boolean
  disabled?: boolean
  checked?: boolean
}

interface MenuDefinition {
  id: 'file' | 'options' | 'window' | 'help'
  label: string
  mnemonic: string
  items: Win31MenuItemModel[]
}

function renderMnemonic(label: string): JSX.Element {
  const marker = label.indexOf('&')
  if (marker < 0) return <>{label}</>
  return <>{label.slice(0, marker)}<u>{label[marker + 1]}</u>{label.slice(marker + 2)}</>
}

function mnemonicOf(label = ''): string | null {
  const marker = label.indexOf('&')
  return marker >= 0 ? label[marker + 1].toLowerCase() : null
}

export function Win31PopupMenu({
  items,
  onCommand,
  onDismiss,
  className = ''
}: {
  items: Win31MenuItemModel[]
  onCommand: (command: Win31Command) => void
  onDismiss: () => void
  className?: string
}): JSX.Element {
  const enabledIndexes = useMemo(() => items
    .map((item, index) => !item.separator && !item.disabled ? index : -1)
    .filter((index) => index >= 0), [items])
  const [highlighted, setHighlighted] = useState(enabledIndexes[0] ?? -1)

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent): void => {
      if (event.key === 'Escape') {
        event.preventDefault()
        onDismiss()
        return
      }
      if (event.key === 'Home' || event.key === 'End') {
        event.preventDefault()
        setHighlighted(event.key === 'Home' ? (enabledIndexes[0] ?? -1) : (enabledIndexes.at(-1) ?? -1))
        return
      }
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault()
        const current = Math.max(0, enabledIndexes.indexOf(highlighted))
        const offset = event.key === 'ArrowDown' ? 1 : -1
        setHighlighted(enabledIndexes[(current + offset + enabledIndexes.length) % enabledIndexes.length] ?? -1)
        return
      }
      if ((event.key === 'Enter' || event.key === ' ') && highlighted >= 0) {
        event.preventDefault()
        const command = items[highlighted]?.command
        if (command) onCommand(command)
        return
      }
      const match = items.find((item) => !item.disabled && mnemonicOf(item.label) === event.key.toLowerCase())
      if (match?.command) {
        event.preventDefault()
        onCommand(match.command)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [enabledIndexes, highlighted, items, onCommand, onDismiss])

  return (
    <div className={`wfw-popup-menu ${className}`} role="menu">
      {items.map((item, index) => item.separator ? (
        <div key={`separator-${index}`} className="wfw-menu-separator" role="separator" />
      ) : (
        <button
          key={`${item.command ?? item.label}-${index}`}
          className={`wfw-popup-item ${highlighted === index ? 'highlighted' : ''}`}
          disabled={item.disabled}
          role="menuitem"
          onPointerEnter={() => { if (!item.disabled) setHighlighted(index) }}
          onClick={() => item.command && onCommand(item.command)}
        >
          <span className="wfw-menu-check" aria-hidden="true">{item.checked ? '✓' : ''}</span>
          <span>{renderMnemonic(item.label ?? '')}</span>
        </button>
      ))}
    </div>
  )
}

export function Win31MenuBar({
  groups,
  activeGroupId,
  commandState,
  onCommand,
  disabled = false
}: {
  groups: ProgramGroup[]
  activeGroupId: string | null
  commandState: (command: Win31Command) => Win31CommandState
  onCommand: (command: Win31Command) => void
  disabled?: boolean
}): JSX.Element {
  const [activeMenu, setActiveMenu] = useState<MenuDefinition['id'] | null>(null)
  const menuBarRef = useRef<HTMLDivElement>(null)

  const definitions = useMemo<MenuDefinition[]>(() => [
    {
      id: 'file', label: '&File', mnemonic: 'f', items: [
        { command: 'new', label: '&New...' },
        { command: 'open', label: '&Open', ...commandState('open') },
        { separator: true },
        { command: 'move', label: '&Move...', ...commandState('move') },
        { command: 'copy', label: '&Copy...', ...commandState('copy') },
        { command: 'delete', label: '&Delete', ...commandState('delete') },
        { command: 'properties', label: '&Properties...', ...commandState('properties') },
        { separator: true },
        { command: 'run', label: '&Run...' },
        { separator: true },
        { command: 'exit', label: 'E&xit Windows...' }
      ]
    },
    {
      id: 'options', label: '&Options', mnemonic: 'o', items: [
        { command: 'auto-arrange', label: '&Auto Arrange', ...commandState('auto-arrange') },
        { command: 'minimize-on-use', label: '&Minimize on Use', ...commandState('minimize-on-use') },
        { command: 'save-settings', label: '&Save Settings on Exit', ...commandState('save-settings') }
      ]
    },
    {
      id: 'window', label: '&Window', mnemonic: 'w', items: [
        { command: 'cascade', label: '&Cascade', ...commandState('cascade') },
        { command: 'tile', label: '&Tile', ...commandState('tile') },
        { command: 'arrange-icons', label: '&Arrange Icons', ...commandState('arrange-icons') },
        ...(groups.length ? [
          { separator: true } as Win31MenuItemModel,
          ...groups.map((group, index): Win31MenuItemModel => ({
            command: `group:${group.id}`,
            label: `${index < 9 ? `&${index + 1} ` : ''}${group.name}`,
            checked: group.id === activeGroupId
          }))
        ] : [])
      ]
    },
    {
      id: 'help', label: '&Help', mnemonic: 'h', items: [
        { command: 'help-contents', label: '&Contents' },
        { command: 'help-search', label: '&Search for Help On...' },
        { command: 'help-using', label: '&How to Use Help' },
        { separator: true },
        { command: 'about', label: '&About Program Manager...' }
      ]
    }
  ], [activeGroupId, commandState, groups])

  const execute = (command: Win31Command): void => {
    setActiveMenu(null)
    onCommand(command)
  }

  useEffect(() => {
    const keyDown = (event: KeyboardEvent): void => {
      if (disabled) return
      if (event.key === 'F10') {
        event.preventDefault()
        setActiveMenu((menu) => menu ? null : 'file')
        return
      }
      if (event.altKey && !event.ctrlKey && !event.metaKey) {
        const definition = definitions.find((menu) => menu.mnemonic === event.key.toLowerCase())
        if (definition) {
          event.preventDefault()
          setActiveMenu(definition.id)
          return
        }
      }
      if (!activeMenu) return
      const menuIndex = definitions.findIndex((menu) => menu.id === activeMenu)
      if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
        event.preventDefault()
        const offset = event.key === 'ArrowRight' ? 1 : -1
        setActiveMenu(definitions[(menuIndex + offset + definitions.length) % definitions.length].id)
      }
    }
    window.addEventListener('keydown', keyDown)
    return () => window.removeEventListener('keydown', keyDown)
  }, [activeMenu, definitions, disabled])

  useEffect(() => {
    if (!activeMenu) return
    const dismiss = (event: PointerEvent): void => {
      if (!menuBarRef.current?.contains(event.target as Node)) setActiveMenu(null)
    }
    window.addEventListener('pointerdown', dismiss)
    return () => window.removeEventListener('pointerdown', dismiss)
  }, [activeMenu])

  return (
    <div className="wfw-menu-bar" ref={menuBarRef} role="menubar">
      {definitions.map((definition) => (
        <div className="wfw-menu-root" key={definition.id}>
          <button
            className={`wfw-menu-button ${activeMenu === definition.id ? 'pressed' : ''}`}
            role="menuitem"
            onPointerDown={(event) => {
              if (disabled) return
              event.preventDefault()
              setActiveMenu((menu) => menu === definition.id ? null : definition.id)
            }}
            onPointerEnter={() => { if (activeMenu) setActiveMenu(definition.id) }}
          >
            <span className="wfw-menu-label">{renderMnemonic(definition.label)}</span>
          </button>
          {activeMenu === definition.id && (
            <Win31PopupMenu items={definition.items} onCommand={execute} onDismiss={() => setActiveMenu(null)} />
          )}
        </div>
      ))}
    </div>
  )
}
