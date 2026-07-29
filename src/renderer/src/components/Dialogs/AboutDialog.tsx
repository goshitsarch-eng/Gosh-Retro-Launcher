import React, { useEffect, useState } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { useUIStore } from '@/store/uiStore'
import { APP_ICON } from '@/utils/icons'
import { useProgramStore } from '@/store/programStore'
import { getWfwIconSrc } from '@/shells/win31/iconCatalog'

export const AboutDialog: React.FC = () => {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const shell = useProgramStore((state) => state.settings.shell)
  const [platform, setPlatform] = useState('')
  const [version, setVersion] = useState('')

  useEffect(() => {
    let cancelled = false
    void window.electronAPI.system.getPlatform().then((value) => {
      if (cancelled) return
      const names: Record<string, string> = { win32: 'Windows', darwin: 'macOS', linux: 'Linux' }
      setPlatform(names[value] || value)
    }).catch(() => !cancelled && setPlatform('Unknown'))
    void window.electronAPI.system.getVersion().then((value) => {
      if (!cancelled) setVersion(value)
    }).catch(() => !cancelled && setVersion('Unknown'))
    return () => { cancelled = true }
  }, [])

  return (
    <Dialog title="About Program Manager" onClose={closeDialog} width={360}>
      <div className="win31-about-content">
        <img src={shell === 'win31' ? getWfwIconSrc('program-manager', 1) : APP_ICON} alt="Program Manager" className="win31-about-icon" />
        <div className="win31-about-copy">
          <div className="win31-about-title">Program Manager</div>
          <div className="win31-about-version">Version {version}</div>
          <div className="win31-about-copyright">Copyright © 2025</div>
          <div className="win31-about-rule" />
          <div className="win31-about-info">Windows 3.11 Program Manager-compatible launcher</div>
          <div className="win31-about-rule" />
          <div className="win31-about-info">Running on {platform}</div>
        </div>
      </div>
      <div className="win31-dialog-buttons">
        <Button onClick={closeDialog} isDefault autoFocus>OK</Button>
      </div>
    </Dialog>
  )
}
