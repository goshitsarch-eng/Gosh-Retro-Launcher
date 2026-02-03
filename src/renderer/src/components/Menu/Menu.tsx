import React, { useRef, useEffect } from 'react'
import { useUIStore } from '@/store/uiStore'

interface MenuProps {
  label: string
  hotkey?: string
  isOpen: boolean
  onClick: () => void
  onHover: () => void
  children: React.ReactNode
}

export const Menu: React.FC<MenuProps> = ({
  label,
  hotkey,
  isOpen,
  onClick,
  onHover,
  children
}) => {
  const menuRef = useRef<HTMLDivElement>(null)
  const setActiveMenu = useUIStore((state) => state.setActiveMenu)

  // Close menu when clicking outside
  useEffect(() => {
    if (!isOpen) return

    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setActiveMenu(null)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [isOpen, setActiveMenu])

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

  return (
    <div
      ref={menuRef}
      className={`win31-menu ${isOpen ? 'open' : ''}`}
    >
      <button
        className="win31-menu-trigger"
        onClick={onClick}
        onMouseEnter={onHover}
      >
        {renderLabel()}
      </button>
      {isOpen && <div className="win31-dropdown">{children}</div>}
    </div>
  )
}
