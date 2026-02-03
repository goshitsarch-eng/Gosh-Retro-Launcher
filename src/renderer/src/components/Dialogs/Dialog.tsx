import React, { useEffect, useCallback, useRef } from 'react'

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

  // Save and restore focus
  useEffect(() => {
    previousFocusRef.current = document.activeElement
    // Focus the dialog container
    dialogRef.current?.focus()

    return () => {
      if (previousFocusRef.current instanceof HTMLElement) {
        previousFocusRef.current.focus()
      }
    }
  }, [])

  // Handle escape key and focus trap
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose()
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
  }, [onClose])

  // Prevent clicks inside dialog from closing it
  const handleDialogClick = useCallback((event: React.MouseEvent) => {
    event.stopPropagation()
  }, [])

  return (
    <div className="win31-dialog-overlay" onClick={onClose} role="dialog" aria-modal="true" aria-label={title}>
      <div
        ref={dialogRef}
        className="win31-dialog"
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
