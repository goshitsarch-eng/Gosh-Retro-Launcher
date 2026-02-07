import React, { useEffect, useCallback, useRef, useState } from 'react'
import { useSounds } from '@/hooks/useSounds'

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
  const [isClosing, setIsClosing] = useState(false)

  // Save and restore focus
  useEffect(() => {
    previousFocusRef.current = document.activeElement
    // Focus the dialog container
    dialogRef.current?.focus()
    sounds.dialogOpen()

    return () => {
      if (previousFocusRef.current instanceof HTMLElement) {
        previousFocusRef.current.focus()
      }
    }
  }, [])

  const handleAnimatedClose = useCallback(() => {
    if (isClosing) return
    setIsClosing(true)
    setTimeout(() => onClose(), 100)
  }, [isClosing, onClose])

  // Handle escape key and focus trap
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
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

  // Prevent clicks inside dialog from closing it
  const handleDialogClick = useCallback((event: React.MouseEvent) => {
    event.stopPropagation()
  }, [])

  return (
    <div
      className={`win31-dialog-overlay anim-overlay-fade-in`}
      onClick={handleAnimatedClose}
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <div
        ref={dialogRef}
        className={`win31-dialog ${isClosing ? 'anim-dialog-close' : 'anim-dialog-open'}`}
        style={{ width }}
        onClick={handleDialogClick}
        tabIndex={-1}
      >
        <div className="win31-titlebar">
          <span className="win31-titlebar-text">{title}</span>
        </div>
        <div className="win31-dialog-content">{children}</div>
      </div>
    </div>
  )
}
