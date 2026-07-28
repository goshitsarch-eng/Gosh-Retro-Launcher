import React, { useEffect, useRef, useState } from 'react'

interface MenuItemProps {
  label: string
  hotkey?: string
  shortcut?: string
  disabled?: boolean
  checkbox?: boolean
  checked?: boolean
  hasSubmenu?: boolean
  submenu?: React.ReactNode
  onClick?: () => void
}

export const MenuItem: React.FC<MenuItemProps> = ({
  label,
  hotkey,
  shortcut,
  disabled = false,
  checkbox = false,
  checked = false,
  hasSubmenu = false,
  submenu,
  onClick
}) => {
  const [showSubmenu, setShowSubmenu] = useState(false)
  const [isActive, setIsActive] = useState(false)
  const focusFrameRef = useRef<number | null>(null)

  useEffect(() => () => {
    if (focusFrameRef.current !== null) window.cancelAnimationFrame(focusFrameRef.current)
  }, [])

  // Render label with hotkey underlined
  const renderLabel = () => {
    if (!hotkey) return label

    const index = label.toLowerCase().indexOf(hotkey.toLowerCase())
    if (index === -1) return label

    return (
      <>
        {label.slice(0, index)}
        <span className="hotkey">{label[index]}</span>
        {label.slice(index + 1)}
      </>
    )
  }

  const handleClick = () => {
    if (disabled) return
    if (hasSubmenu) return
    onClick?.()
  }

  const handleMouseEnter = () => {
    if (hasSubmenu) {
      setShowSubmenu(true)
    }
  }

  const handleMouseLeave = () => {
    if (hasSubmenu) {
      setShowSubmenu(false)
    }
  }

  const classNames = [
    'win31-menu-item',
    disabled && 'disabled',
    checkbox && 'checkbox',
    checkbox && checked && 'checked',
    hasSubmenu && 'has-submenu',
    isActive && 'active'
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <div
      className={classNames}
      role={checkbox ? 'menuitemcheckbox' : 'menuitem'}
      tabIndex={-1}
      data-hotkey={hotkey?.toLowerCase()}
      aria-checked={checkbox ? checked : undefined}
      aria-disabled={disabled || undefined}
      aria-haspopup={hasSubmenu ? 'menu' : undefined}
      aria-expanded={hasSubmenu ? showSubmenu : undefined}
      onClick={handleClick}
      onPointerDown={() => !disabled && setIsActive(true)}
      onPointerUp={() => setIsActive(false)}
      onPointerCancel={() => setIsActive(false)}
      onBlur={() => setIsActive(false)}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={() => {
        setIsActive(false)
        handleMouseLeave()
      }}
      onKeyDown={(event) => {
        if ((event.key === 'Enter' || event.key === ' ') && !disabled && !hasSubmenu) {
          event.preventDefault()
          setIsActive(true)
          handleClick()
        } else if (event.key === 'ArrowRight' && hasSubmenu) {
          event.preventDefault()
          event.stopPropagation()
          const item = event.currentTarget
          setShowSubmenu(true)
          if (focusFrameRef.current !== null) window.cancelAnimationFrame(focusFrameRef.current)
          focusFrameRef.current = window.requestAnimationFrame(() => {
            focusFrameRef.current = null
            item.querySelector<HTMLElement>('.win31-submenu .win31-menu-item:not(.disabled)')?.focus()
          })
        } else if (event.key === 'ArrowLeft' && hasSubmenu && showSubmenu) {
          event.preventDefault()
          event.stopPropagation()
          setShowSubmenu(false)
          event.currentTarget.focus()
        }
      }}
    >
      {renderLabel()}
      {shortcut && <span className="shortcut">{shortcut}</span>}
      {hasSubmenu && showSubmenu && (
        <span className="win31-submenu" role="menu">{submenu}</span>
      )}
    </div>
  )
}
