import React from 'react'
import { Button } from '../Common/Button'

interface MDIWindowControlsProps {
  onMinimize: () => void
  onMaximize: () => void
  onClose: () => void
  isMaximized: boolean
}

export const MDIWindowControls: React.FC<MDIWindowControlsProps> = ({
  onMinimize,
  onMaximize,
  onClose,
  isMaximized
}) => {
  return (
    <div className="win31-titlebar-controls">
      <Button
        small
        onClick={(e) => {
          e.stopPropagation()
          onMinimize()
        }}
        title="Minimize"
        aria-label="Minimize"
      >
        <span className="win31-glyph-minimize" />
      </Button>
      <Button
        small
        onClick={(e) => {
          e.stopPropagation()
          onMaximize()
        }}
        title={isMaximized ? 'Restore' : 'Maximize'}
        aria-label={isMaximized ? 'Restore' : 'Maximize'}
      >
        <span className={isMaximized ? 'win31-glyph-restore' : 'win31-glyph-maximize'} />
      </Button>
    </div>
  )
}
