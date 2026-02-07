import React, { useState, useEffect } from 'react'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { getIconSrc, APP_ICON } from '@/utils/icons'

interface Win95TaskbarProps {
  onStartClick: () => void
  startMenuOpen: boolean
}

function formatTime(): string {
  const now = new Date()
  return now.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}

export const Win95Taskbar: React.FC<Win95TaskbarProps> = ({ onStartClick, startMenuOpen }) => {
  const groups = useProgramStore((state) => state.groups)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const windows = useMDIStore((state) => state.windows)
  const activeWindowId = useMDIStore((state) => state.activeWindowId)
  const focusWindow = useMDIStore((state) => state.focusWindow)
  const closeWindow = useMDIStore((state) => state.closeWindow)
  const [clock, setClock] = useState(formatTime)

  useEffect(() => {
    const interval = setInterval(() => setClock(formatTime()), 60000)
    return () => clearInterval(interval)
  }, [])

  // Only show taskbar buttons for windows that exist in mdiStore
  const openGroupIds = new Set(windows.map((w) => w.groupId))
  const taskbarGroups = groups.filter((g) => openGroupIds.has(g.id))

  const handleWindowButtonClick = (groupId: string, minimized: boolean): void => {
    if (minimized) {
      // Restore and focus
      updateGroupWindowState(groupId, { minimized: false })
      focusWindow(groupId)
    } else if (activeWindowId === groupId) {
      // Currently focused + visible -> minimize to taskbar
      updateGroupWindowState(groupId, { minimized: true })
    } else {
      // Visible but not focused -> focus
      focusWindow(groupId)
    }
  }

  return (
    <div className="win95-taskbar">
      <button
        className={`win95-start-button ${startMenuOpen ? 'active' : ''}`}
        onMouseDown={(e) => {
          e.stopPropagation()
          onStartClick()
        }}
      >
        <img src={APP_ICON} alt="" className="win95-start-button-icon" draggable={false} />
        Start
      </button>

      <div className="win95-taskbar-separator" />

      <div className="win95-taskbar-windows">
        {taskbarGroups.map((group) => {
          const isActive = activeWindowId === group.id && !group.windowState.minimized
          return (
            <button
              key={group.id}
              className={`win95-taskbar-button ${isActive ? 'active' : ''}`}
              onClick={() => handleWindowButtonClick(group.id, group.windowState.minimized)}
              title={group.name}
            >
              <img
                src={getIconSrc(group.icon)}
                alt=""
                className="win95-taskbar-button-icon"
                draggable={false}
              />
              <span className="win95-taskbar-button-label">{group.name}</span>
            </button>
          )
        })}
      </div>

      <div className="win95-system-tray">{clock}</div>
    </div>
  )
}
