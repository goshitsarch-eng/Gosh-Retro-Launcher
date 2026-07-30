import { type CSSProperties, type JSX } from 'react'
import { Win95Desktop } from './Win95Desktop'
import { Win95Taskbar } from './Win95Taskbar'
import { Win95StartMenu } from './Win95StartMenu'
import { Win95ScaleProvider, useWin95Scale } from './Win95ScaleContext'
import { Win95DialogManager } from './Win95Dialogs'
import { Win95InputControllerProvider, useWin95InputController } from './Win95InputController'
import type { ShellProps } from '../types'

export const Win95Shell = (_props: ShellProps): JSX.Element => (
  <Win95ScaleProvider>
    <Win95InputControllerProvider>
      <Win95ShellDesktop />
    </Win95InputControllerProvider>
  </Win95ScaleProvider>
)

function Win95ShellDesktop(): JSX.Element {
  const { startMenuOpen, closeStartMenu, toggleStartMenu } = useWin95InputController()
  const { scale, logicalViewport } = useWin95Scale()

  const scaleStyle = {
    '--win95-scale': scale,
    width: logicalViewport.width,
    height: logicalViewport.height,
    transform: `scale(${scale})`
  } as CSSProperties

  return (
    <div className="win95-scale-viewport">
      <div className="win95-scale-root" style={scaleStyle} data-scale={scale}>
        <div className="win95-shell">
          <Win95Desktop />
          <Win95StartMenu isOpen={startMenuOpen} onClose={closeStartMenu} />
          <Win95Taskbar onStartClick={toggleStartMenu} startMenuOpen={startMenuOpen} />
          <Win95DialogManager />
        </div>
      </div>
    </div>
  )
}
