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
      >
        ▼
      </Button>
      <Button
        small
        onClick={(e) => {
          e.stopPropagation()
          onMaximize()
        }}
        title={isMaximized ? 'Restore' : 'Maximize'}
      >
        {isMaximized ? '◇' : '▲'}
      </Button>
    </div>
  )
}
