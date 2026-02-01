import React, { useEffect, useState } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { useUIStore } from '@/store/uiStore'
import { APP_ICON } from '@/utils/icons'

export const AboutDialog: React.FC = () => {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const [platform, setPlatform] = useState<string>('')

  useEffect(() => {
    window.electronAPI.system.getPlatform().then((p) => {
      const platformNames: Record<string, string> = {
        win32: 'Windows',
        darwin: 'macOS',
        linux: 'Linux'
      }
      setPlatform(platformNames[p] || p)
    }).catch(() => {
      setPlatform('Unknown')
    })
  }, [])

  return (
    <Dialog title="About Program Manager" onClose={closeDialog} width={350}>
      <div className="win31-about-content">
        <img
          src={APP_ICON}
          alt="Program Manager"
          className="win31-about-icon"
          style={{ width: 48, height: 48, imageRendering: 'pixelated' }}
        />

        <div className="win31-about-title">Program Manager</div>
        <div className="win31-about-version">Version 1.0.0</div>

        <hr className="win31-about-separator" />

        <div className="win31-about-info">
          A Windows 3.1 Program Manager clone
          <br />
          built with Electron and React.
        </div>

        <div className="win31-about-info" style={{ marginTop: 8 }}>
          Running on {platform}
        </div>

        <hr className="win31-about-separator" />

        <div className="win31-about-info" style={{ fontSize: 10 }}>
          © 2024. Made with nostalgia.
        </div>
      </div>

      <div className="win31-dialog-buttons">
        <Button onClick={closeDialog} isDefault autoFocus>
          OK
        </Button>
      </div>
    </Dialog>
  )
}
