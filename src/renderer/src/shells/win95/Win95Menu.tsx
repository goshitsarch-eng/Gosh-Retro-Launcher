import { useEffect, useId, useRef, useState, type JSX } from 'react'
import { getWin95IconSrc } from './iconCatalog'
import { useWin95Scale } from './Win95ScaleContext'
import { mnemonicIndex } from './menuState'
import { Win95BitmapText } from './bitmapText'
import { Win95Glyph } from './Win95Primitives'
import { useWin95InputHandler, useWin95MenuScope, useWin95PointerHandler } from './Win95InputController'
import { WIN95_METRICS } from './tokens'

export interface Win95MenuItemModel {
  id: string
  label?: string
  icon?: string
  separator?: boolean
  disabled?: boolean
  checked?: boolean
  radio?: boolean
  defaultItem?: boolean
  children?: Win95MenuItemModel[]
  onSelect?: () => void
}

interface Win95PopupMenuProps {
  items: Win95MenuItemModel[]
  x?: number
  y?: number
  className?: string
  selectedId?: string | null
  onHover?: (id: string, item: Win95MenuItemModel, target: HTMLElement) => void
  onClose?: () => void
  onSelect?: (item: Win95MenuItemModel) => void
  roleLabel?: string
  parentLevel?: number
  bottomInset?: number
}

export function Win95PopupMenu({
  items,
  x,
  y,
  className = '',
  selectedId,
  onHover,
  onClose,
  onSelect,
  roleLabel = 'Menu',
  parentLevel = 0,
  bottomInset = 0
}: Win95PopupMenuProps): JSX.Element {
  const ref = useRef<HTMLDivElement>(null)
  const id = useId()
  const { scale, logicalViewport } = useWin95Scale()
  const [placement, setPlacement] = useState({ x, y })
  const [localSelected, setLocalSelected] = useState<string | null>(() => selectedId ?? items.find((item) => !item.separator && !item.disabled)?.id ?? null)
  const [child, setChild] = useState<{ item: Win95MenuItemModel; x: number; y: number } | null>(null)
  const [tracking, setTracking] = useState(false)
  const delayRef = useRef<number | null>(null)
  const suppressClick = useRef(false)
  const currentSelected = selectedId ?? localSelected

  const clearDelay = (): void => {
    if (delayRef.current) window.clearTimeout(delayRef.current)
    delayRef.current = null
  }
  const selectItem = (item: Win95MenuItemModel, target?: HTMLElement): void => {
    if (item.separator || item.disabled) return
    setLocalSelected(item.id)
    if (target) onHover?.(item.id, item, target)
    clearDelay()
    if (!item.children?.length || !target) {
      if (child) delayRef.current = window.setTimeout(() => setChild(null), WIN95_METRICS.submenuDelayMs)
      else setChild(null)
      return
    }
    const root = target.closest('.win95-scale-root')?.getBoundingClientRect()
    const bounds = target.closest('.win95-popup-menu')?.getBoundingClientRect()
    const row = target.getBoundingClientRect()
    delayRef.current = window.setTimeout(() => {
      const estimatedWidth = 176
      const right = (bounds?.right ?? row.right) - (root?.left ?? 0)
      const left = (bounds?.left ?? row.left) - (root?.left ?? 0)
      const childX = right / scale - 1 + estimatedWidth > logicalViewport.width
        ? left / scale - estimatedWidth + 1
        : right / scale - 1
      setChild({ item, x: childX, y: (row.top - (root?.top ?? 0)) / scale })
    }, WIN95_METRICS.submenuDelayMs)
  }
  const activateItem = (item: Win95MenuItemModel | undefined): boolean => {
    if (!item || item.disabled || item.separator) return false
    if (item.children?.length) {
      const button = ref.current?.querySelector<HTMLElement>(`[data-menu-item="${CSS.escape(item.id)}"]`)
      if (button) selectItem(item, button)
      return true
    }
    item.onSelect?.()
    onSelect?.(item)
    onClose?.()
    return true
  }

  useEffect(() => {
    const element = ref.current
    if (x === undefined || y === undefined || !element) { setPlacement({ x, y }); return }
    const bounds = element.getBoundingClientRect()
    setPlacement({
      x: Math.round(Math.max(0, Math.min(x, logicalViewport.width - bounds.width / scale))),
      y: Math.round(Math.max(0, Math.min(y, logicalViewport.height - bottomInset - bounds.height / scale)))
    })
  }, [bottomInset, logicalViewport.height, logicalViewport.width, scale, x, y])

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const item = items.find((candidate) => candidate.id === currentSelected && !candidate.disabled) ?? items.find((candidate) => !candidate.separator && !candidate.disabled)
      if (!item) return
      setLocalSelected(item.id)
      ref.current?.querySelector<HTMLButtonElement>(`[data-menu-item="${CSS.escape(item.id)}"]`)?.focus()
    }, 0)
    return () => { window.clearTimeout(timer); clearDelay() }
  }, [])

  useWin95MenuScope(`popup-${id}`, true)
  useWin95PointerHandler('pointerdown', `popup-outside-${id}`, (event) => {
    const target = event.target as HTMLElement
    if (ref.current?.contains(target) || target.closest('.win95-popup-menu')) return false
    onClose?.()
    return true
  })
  useWin95PointerHandler('pointerup', `popup-track-${id}`, (event) => {
    if (!tracking) return false
    setTracking(false)
    const button = (event.target as HTMLElement).closest<HTMLElement>('[data-menu-item]')
    if (!button || !ref.current?.contains(button)) return false
    const item = items.find((candidate) => candidate.id === button.dataset.menuItem)
    if (!item || item.children?.length) return false
    suppressClick.current = true
    queueMicrotask(() => { suppressClick.current = false })
    return activateItem(item)
  }, tracking)

  useWin95InputHandler('menu', `popup-key-${id}`, (event) => {
    const selectable = items.filter((item) => !item.separator && !item.disabled)
    if (!selectable.length) return event.key === 'Escape'
    let index = selectable.findIndex((item) => item.id === currentSelected)
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp' || event.key === 'Home' || event.key === 'End') {
      if (event.key === 'Home') index = 0
      else if (event.key === 'End') index = selectable.length - 1
      else if (event.key === 'ArrowDown') index = (index + 1 + selectable.length) % selectable.length
      else index = (index - 1 + selectable.length) % selectable.length
      const item = selectable[index]
      setLocalSelected(item.id)
      ref.current?.querySelector<HTMLButtonElement>(`[data-menu-item="${CSS.escape(item.id)}"]`)?.focus()
      return true
    }
    const item = selectable[Math.max(0, index)]
    if (event.key === 'ArrowRight' && item?.children?.length) return activateItem(item)
    if (event.key === 'ArrowLeft' && parentLevel > 0) { onClose?.(); return true }
    if (event.key === 'Enter') return activateItem(item)
    if (event.key === 'Escape') { onClose?.(); return true }
    if (event.key.length === 1) {
      const match = mnemonicIndex(selectable.map((candidate) => candidate.label ?? ''), event.key)
      if (match >= 0) { setLocalSelected(selectable[match].id); activateItem(selectable[match]); return true }
    }
    return false
  })

  return (
    <>
      <div
        ref={ref}
        className={`win95-popup-menu ${className}`}
        style={{ left: placement.x, top: placement.y }}
        role="menu"
        aria-label={roleLabel}
        onContextMenu={(event) => event.preventDefault()}
      >
        {items.map((item) => {
          if (item.separator) return <div key={item.id} className="win95-menu-separator" role="separator" />
          return (
            <button
              type="button"
              key={item.id}
              data-menu-item={item.id}
              className={`win95-popup-item ${currentSelected === item.id ? 'selected' : ''} ${item.defaultItem ? 'default-item' : ''}`}
              role={item.radio ? 'menuitemradio' : item.checked !== undefined ? 'menuitemcheckbox' : 'menuitem'}
              disabled={item.disabled}
              aria-checked={item.radio || item.checked !== undefined ? !!item.checked : undefined}
              aria-haspopup={item.children?.length ? 'menu' : undefined}
              onFocus={() => setLocalSelected(item.id)}
              onPointerDown={(event) => { if (event.button === 0) { setTracking(true); selectItem(item, event.currentTarget) } }}
              onPointerEnter={(event) => selectItem(item, event.currentTarget)}
              onClick={(event) => {
                event.stopPropagation()
                if (suppressClick.current) return
                activateItem(item)
              }}
            >
              <span className="win95-menu-check">{item.checked ? <Win95Glyph name={item.radio ? 'menu-radio' : 'menu-check'} color={currentSelected === item.id ? '#ffffff' : '#000000'} /> : null}</span>
              {item.icon ? <img src={getWin95IconSrc(item.icon, 'small', scale)} alt="" /> : <span className="win95-menu-icon-space" />}
              <Win95BitmapText className="win95-menu-label" text={item.label ?? ''} bold={item.defaultItem} disabled={item.disabled} color={currentSelected === item.id ? '#ffffff' : '#000000'} />
              {item.children?.length ? <span className="win95-menu-arrow"><Win95Glyph name="menu-right" color={currentSelected === item.id ? '#ffffff' : '#000000'} /></span> : null}
            </button>
          )
        })}
      </div>
      {child?.item.children?.length ? <Win95PopupMenu
        items={child.item.children}
        x={child.x}
        y={child.y}
        parentLevel={parentLevel + 1}
        onClose={() => setChild(null)}
        onSelect={(item) => { onSelect?.(item); onClose?.() }}
        roleLabel={child.item.label?.replace(/&/g, '') ?? 'Submenu'}
        bottomInset={bottomInset}
      /> : null}
    </>
  )
}
