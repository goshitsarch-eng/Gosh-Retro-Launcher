import React, { useEffect, useCallback, useRef, useState } from 'react'
import { useSounds } from '@/hooks/useSounds'
import { useProgramStore } from '@/store/programStore'

interface DialogProps {
  title: string
  onClose: () => void
  children: React.ReactNode
  width?: number
}

export const Dialog: React.FC<DialogProps> = ({
  title,
  onClose,
  children,
  width = 400
}) => {
  const dialogRef = useRef<HTMLDivElement>(null)
  const previousFocusRef = useRef<Element | null>(null)
  const sounds = useSounds()
  const shell = useProgramStore((state) => state.settings.shell)
  const [isClosing, setIsClosing] = useState(false)
  const [position, setPosition] = useState({ x: 0, y: 0 })
  const [systemMenuOpen, setSystemMenuOpen] = useState(false)
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const keyboardMoveCleanupRef = useRef<(() => void) | null>(null)

  // Save and restore focus
  useEffect(() => {
    previousFocusRef.current = document.activeElement
    // Focus the dialog container
    dialogRef.current?.focus()
    sounds.dialogOpen()

    return () => {
      if (closeTimerRef.current !== null) {
        clearTimeout(closeTimerRef.current)
        closeTimerRef.current = null
      }
      keyboardMoveCleanupRef.current?.()
      keyboardMoveCleanupRef.current = null
      if (previousFocusRef.current instanceof HTMLElement) {
        previousFocusRef.current.focus()
      }
    }
  }, [sounds])

  const handleAnimatedClose = useCallback(() => {
    if (isClosing) return
    setIsClosing(true)
    if (closeTimerRef.current !== null) clearTimeout(closeTimerRef.current)
    closeTimerRef.current = setTimeout(() => {
      closeTimerRef.current = null
      onClose()
    }, 100)
  }, [isClosing, onClose])

  // Handle escape key and focus trap
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (keyboardMoveCleanupRef.current) return
      if (event.key === 'Escape') {
        handleAnimatedClose()
        return
      }

      // Focus trap on Tab
      if (event.key === 'Tab' && dialogRef.current) {
        const focusable = dialogRef.current.querySelectorAll<HTMLElement>(
          'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
        )
        if (focusable.length === 0) return

        const first = focusable[0]
        const last = focusable[focusable.length - 1]

        if (event.shiftKey) {
          if (document.activeElement === first) {
            event.preventDefault()
            last.focus()
          }
        } else {
          if (document.activeElement === last) {
            event.preventDefault()
            first.focus()
          }
        }
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [handleAnimatedClose])

  const beginDrag = useCallback((event: React.PointerEvent<HTMLDivElement>) => {
    if ((event.target as HTMLElement).closest('button')) return
    const scale = shell === 'win31'
      ? Number.parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--wfw-ui-scale')) || 1
      : 1
    const start = { x: event.clientX, y: event.clientY, position }
    const element = event.currentTarget
    element.setPointerCapture(event.pointerId)
    const move = (pointer: PointerEvent): void => setPosition({
      x: Math.round(start.position.x + (pointer.clientX - start.x) / scale),
      y: Math.round(start.position.y + (pointer.clientY - start.y) / scale)
    })
    const end = (): void => {
      element.removeEventListener('pointermove', move)
      element.removeEventListener('pointerup', end)
      element.removeEventListener('pointercancel', end)
    }
    element.addEventListener('pointermove', move)
    element.addEventListener('pointerup', end)
    element.addEventListener('pointercancel', end)
  }, [position, shell])

  const beginKeyboardMove = useCallback(() => {
    setSystemMenuOpen(false)
    keyboardMoveCleanupRef.current?.()
    const original = { ...position }
    let next = { ...position }
    const keyDown = (event: KeyboardEvent): void => {
      if (event.key === 'Escape' || event.key === 'Enter') {
        event.preventDefault()
        document.removeEventListener('keydown', keyDown)
        keyboardMoveCleanupRef.current = null
        if (event.key === 'Escape') setPosition(original)
        return
      }
      const step = event.shiftKey ? 8 : 1
      if (event.key === 'ArrowLeft') next.x -= step
      else if (event.key === 'ArrowRight') next.x += step
      else if (event.key === 'ArrowUp') next.y -= step
      else if (event.key === 'ArrowDown') next.y += step
      else return
      event.preventDefault()
      setPosition({ ...next })
    }
    document.addEventListener('keydown', keyDown)
    keyboardMoveCleanupRef.current = () => document.removeEventListener('keydown', keyDown)
  }, [position])

  // Prevent clicks inside dialog from closing it
  const handleDialogClick = useCallback((event: React.MouseEvent) => {
    event.stopPropagation()
  }, [])

  return (
    <div
      className={`win31-dialog-overlay anim-overlay-fade-in`}
      onClick={shell === 'win95' ? handleAnimatedClose : undefined}
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <div
        ref={dialogRef}
        className={`win31-dialog ${isClosing ? 'anim-dialog-close' : 'anim-dialog-open'}`}
        style={{ width, left: position.x, top: position.y }}
        onClick={handleDialogClick}
        tabIndex={-1}
      >
        <div className="win31-titlebar" onPointerDown={beginDrag}>
          <button
            type="button"
            className="win31-dialog-system-button"
            aria-label={`Close ${title}`}
            title="Close"
            aria-haspopup="menu"
            aria-expanded={systemMenuOpen}
            onClick={(event) => {
              event.stopPropagation()
              setSystemMenuOpen((open) => !open)
            }}
            onDoubleClick={(event) => {
              event.stopPropagation()
              handleAnimatedClose()
            }}
          >
            <span />
          </button>
          <span className="win31-titlebar-text">{title}</span>
          {systemMenuOpen && (
            <div className="wfw-dialog-system-menu" role="menu" onPointerDown={(event) => event.stopPropagation()}>
              <button type="button" role="menuitem" onClick={beginKeyboardMove}>Move</button>
              <div role="separator" />
              <button type="button" role="menuitem" onClick={handleAnimatedClose}>Close</button>
            </div>
          )}
        </div>
        <div className="win31-dialog-content">{children}</div>
      </div>
    </div>
  )
}
