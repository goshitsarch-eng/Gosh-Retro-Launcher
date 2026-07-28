import React, { useRef, useEffect } from 'react'
import { useUIStore } from '@/store/uiStore'

interface MenuProps {
  label: string
  hotkey?: string
  isOpen: boolean
  onClick: () => void
  onHover: () => void
  onPrevious?: () => void
  onNext?: () => void
  children: React.ReactNode
}

export const Menu: React.FC<MenuProps> = ({
  label,
  hotkey,
  isOpen,
  onClick,
  onHover,
  onPrevious,
  onNext,
  children
}) => {
  const menuRef = useRef<HTMLDivElement>(null)
  const triggerRef = useRef<HTMLButtonElement>(null)
  const dropdownRef = useRef<HTMLDivElement>(null)
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

  useEffect(() => {
    if (!isOpen) return
    const frame = window.requestAnimationFrame(() => {
      dropdownRef.current
        ?.querySelector<HTMLElement>(':scope > .win31-menu-item:not(.disabled)')
        ?.focus()
    })
    return () => window.cancelAnimationFrame(frame)
  }, [isOpen])

  const handleDropdownKeyDown = (event: React.KeyboardEvent<HTMLDivElement>): void => {
    const items = Array.from(
      dropdownRef.current?.querySelectorAll<HTMLElement>(
        ':scope > .win31-menu-item:not(.disabled)'
      ) ?? []
    )
    const currentIndex = items.indexOf(document.activeElement as HTMLElement)

    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault()
      const direction = event.key === 'ArrowDown' ? 1 : -1
      const nextIndex = currentIndex < 0
        ? direction > 0 ? 0 : items.length - 1
        : (currentIndex + direction + items.length) % items.length
      items[nextIndex]?.focus()
      return
    }
    if (event.key === 'Home' || event.key === 'End') {
      event.preventDefault()
      items[event.key === 'Home' ? 0 : items.length - 1]?.focus()
      return
    }
    if (event.key === 'ArrowLeft') {
      event.preventDefault()
      onPrevious?.()
      return
    }
    if (event.key === 'ArrowRight' && !(document.activeElement?.getAttribute('aria-haspopup'))) {
      event.preventDefault()
      onNext?.()
      return
    }
    if (event.key === 'Escape') {
      event.preventDefault()
      setActiveMenu(null)
      triggerRef.current?.focus()
      return
    }
    if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
      const mnemonic = event.key.toLowerCase()
      const item = items.find((candidate) => candidate.dataset.hotkey === mnemonic)
      if (item) {
        event.preventDefault()
        item.focus()
        item.click()
      }
    }
  }

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
        ref={triggerRef}
        type="button"
        className="win31-menu-trigger"
        aria-haspopup="menu"
        aria-expanded={isOpen}
        onClick={onClick}
        onMouseEnter={onHover}
        onKeyDown={(event) => {
          if (event.key === 'ArrowDown') {
            event.preventDefault()
            if (!isOpen) onClick()
          } else if (event.key === 'ArrowLeft') {
            event.preventDefault()
            onPrevious?.()
          } else if (event.key === 'ArrowRight') {
            event.preventDefault()
            onNext?.()
          }
        }}
      >
        {renderLabel()}
      </button>
      {isOpen && (
        <div
          ref={dropdownRef}
          className="win31-dropdown anim-menu-open"
          role="menu"
          onKeyDown={handleDropdownKeyDown}
        >
          {children}
        </div>
      )}
    </div>
  )
}
