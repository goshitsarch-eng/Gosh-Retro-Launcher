import React, { useState, useCallback } from 'react'
import { Dialog } from './Dialog'
import { Button } from '../Common/Button'
import { Checkbox } from '../Common/Checkbox'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'

export const SettingsDialog: React.FC = () => {
  const closeDialog = useUIStore((state) => state.closeDialog)
  const { settings, updateSettings } = useProgramStore()

  const [launchDelay, setLaunchDelay] = useState(settings.launchDelay)
  const [autoArrange, setAutoArrange] = useState(settings.autoArrange)
  const [minimizeOnUse, setMinimizeOnUse] = useState(settings.minimizeOnUse)
  const [saveSettingsOnExit, setSaveSettingsOnExit] = useState(settings.saveSettingsOnExit)
  const [trayOnClose, setTrayOnClose] = useState(settings.trayOnClose)
  const [groupChromeScale, setGroupChromeScale] = useState(settings.groupChromeScale)
  const [theme, setTheme] = useState(settings.theme)

  const handleSubmit = useCallback(
    (event: React.FormEvent) => {
      event.preventDefault()
      updateSettings({
        launchDelay,
        autoArrange,
        minimizeOnUse,
        saveSettingsOnExit,
        trayOnClose,
        groupChromeScale,
        theme
      })
      closeDialog()
    },
    [
      launchDelay,
      autoArrange,
      minimizeOnUse,
      saveSettingsOnExit,
      trayOnClose,
      groupChromeScale,
      theme,
      updateSettings,
      closeDialog
    ]
  )

  return (
    <Dialog title="Settings" onClose={closeDialog} width={400}>
      <form onSubmit={handleSubmit}>
        <div className="win31-groupbox">
          <span className="win31-groupbox-label">General</span>

          <div style={{ marginBottom: 8 }}>
            <Checkbox
              label="Auto Arrange icons"
              checked={autoArrange}
              onChange={(e) => setAutoArrange(e.target.checked)}
            />
          </div>

          <div style={{ marginBottom: 8 }}>
            <Checkbox
              label="Minimize on Use"
              checked={minimizeOnUse}
              onChange={(e) => setMinimizeOnUse(e.target.checked)}
            />
          </div>

          <div style={{ marginBottom: 8 }}>
            <Checkbox
              label="Save Settings on Exit"
              checked={saveSettingsOnExit}
              onChange={(e) => setSaveSettingsOnExit(e.target.checked)}
            />
          </div>

          <div>
            <Checkbox
              label="Minimize to Tray on Close"
              checked={trayOnClose}
              onChange={(e) => setTrayOnClose(e.target.checked)}
            />
          </div>
        </div>

        <div className="win31-groupbox">
          <span className="win31-groupbox-label">Appearance</span>

          <div style={{ marginBottom: 8 }}>
            <Checkbox
              label="Dark Mode"
              checked={theme === 'dark'}
              onChange={(e) => setTheme(e.target.checked ? 'dark' : 'light')}
            />
          </div>

          <div className="win31-slider-row">
            <label>Group Title Bar Size:</label>
            <input
              type="range"
              min={1}
              max={1.6}
              step={0.05}
              value={groupChromeScale}
              onChange={(e) => setGroupChromeScale(Number(e.target.value))}
              style={{ flex: 1 }}
            />
            <span className="value">{Math.round(groupChromeScale * 100)}%</span>
          </div>
        </div>

        <div className="win31-groupbox">
          <span className="win31-groupbox-label">Batch Launch</span>

          <div className="win31-slider-row">
            <label>Delay between launches:</label>
            <input
              type="range"
              min={100}
              max={5000}
              step={100}
              value={launchDelay}
              onChange={(e) => setLaunchDelay(Number(e.target.value))}
              style={{ flex: 1 }}
            />
            <span className="value">{launchDelay}ms</span>
          </div>
        </div>

        <div className="win31-dialog-buttons">
          <Button type="submit" isDefault>
            OK
          </Button>
          <Button type="button" onClick={closeDialog}>
            Cancel
          </Button>
        </div>
      </form>
    </Dialog>
  )
}
