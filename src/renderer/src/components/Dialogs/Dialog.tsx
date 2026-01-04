import React, { useEffect, useCallback } from 'react'

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
  // Handle escape key to close
  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose()
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
    <div className="win31-dialog-overlay" onClick={onClose}>
      <div
        className="win31-dialog"
        style={{ width }}
        onClick={handleDialogClick}
      >
        <div className="win31-titlebar">
          <span className="win31-titlebar-text">{title}</span>
        </div>
        <div className="win31-dialog-content">{children}</div>
      </div>
    </div>
  )
}
