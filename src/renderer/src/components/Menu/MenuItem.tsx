import React, { useState } from 'react'

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
    hasSubmenu && 'has-submenu'
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <div
      className={classNames}
      onClick={handleClick}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {renderLabel()}
      {shortcut && <span className="shortcut">{shortcut}</span>}
      {hasSubmenu && showSubmenu && (
        <div className="win31-submenu">{submenu}</div>
      )}
    </div>
  )
}
