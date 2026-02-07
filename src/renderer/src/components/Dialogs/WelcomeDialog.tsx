import React, { useState, useEffect } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { useUIStore } from '@/store/uiStore'
import { APP_ICON } from '@/utils/icons'

export const WelcomeDialog: React.FC = () => {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const [platform, setPlatform] = useState('linux')

  useEffect(() => {
    window.electronAPI.system.getPlatform().then(setPlatform).catch(() => {})
  }, [])

  const modKey = platform === 'darwin' ? 'Cmd' : 'Ctrl'

  return (
    <Dialog title="Welcome to Program Manager" onClose={closeDialog} width={400}>
      <div style={{ padding: '8px 4px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
          <img
            src={APP_ICON}
            alt="Program Manager"
            style={{ width: 48, height: 48, imageRendering: 'pixelated' }}
          />
          <div>
            <div style={{ fontWeight: 'bold', marginBottom: 2 }}>Program Manager</div>
            <div style={{ fontSize: 11 }}>A retro launcher for your modern desktop</div>
          </div>
        </div>

        <hr className="win31-about-separator" />

        <div style={{ fontSize: 12, lineHeight: 1.5 }}>
          <div style={{ fontWeight: 'bold', marginBottom: 4 }}>Getting started:</div>
          <ul style={{ margin: '0 0 8px 16px', padding: 0 }}>
            <li>Drag files into a group window to add programs</li>
            <li>Use <b>File &rarr; New</b> to create items or groups</li>
            <li>Double-click an item to launch it</li>
            <li>Right-click items for properties</li>
          </ul>

          <div style={{ fontWeight: 'bold', marginBottom: 4 }}>Quick Search:</div>
          <div style={{ marginBottom: 8, marginLeft: 4 }}>
            Press <b>{modKey}+Shift+Space</b> anywhere to quickly find and launch programs.
          </div>

          <div style={{ fontWeight: 'bold', marginBottom: 4 }}>Keyboard shortcuts:</div>
          <ul style={{ margin: '0 0 0 16px', padding: 0 }}>
            <li><b>Alt+F/O/W/H</b> &mdash; Open menus</li>
            <li><b>Enter</b> &mdash; Launch selected item</li>
            <li><b>Delete</b> &mdash; Remove selected item</li>
            <li><b>Shift+F4/F5</b> &mdash; Tile / Cascade windows</li>
          </ul>
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
