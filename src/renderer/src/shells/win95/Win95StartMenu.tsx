import React, { useState, useEffect, useRef } from 'react'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { useUIStore } from '@/store/uiStore'
import { useSounds } from '@/hooks/useSounds'
import { useAnimatedUnmount } from '@/hooks/useAnimatedUnmount'
import { getIconSrc, DEFAULT_FOLDER_ICON } from '@/utils/icons'
import { collectLaunchGroups, launchGroupBuckets } from '@/utils/launchGroups'

interface Win95StartMenuProps {
  isOpen: boolean
  onClose: () => void
}

export const Win95StartMenu: React.FC<Win95StartMenuProps> = ({ isOpen, onClose }) => {
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const openWindow = useMDIStore((state) => state.openWindow)
  const activeWindowId = useMDIStore((state) => state.activeWindowId)
  const {
    openQuickSearch,
    openDialog,
    beginLaunchFeedback,
    updateLaunchFeedback,
    finishLaunchFeedback
  } = useUIStore()
  const sounds = useSounds()
  const { shouldRender, animClass } = useAnimatedUnmount(isOpen, 80)
  const [expandedGroupId, setExpandedGroupId] = useState<string | null>(null)
  const [expandedProgramGroupId, setExpandedProgramGroupId] = useState<string | null>(null)
  const menuRef = useRef<HTMLDivElement>(null)
  const launchGroups = collectLaunchGroups(groups)

  // Click-outside to close
  useEffect(() => {
    if (!isOpen) return

    const handleMouseDown = (event: MouseEvent): void => {
      const target = event.target as HTMLElement
      if (target.closest('.win95-start-button')) return
      if (menuRef.current && !menuRef.current.contains(target)) {
        onClose()
      }
    }

    const timer = setTimeout(() => {
      document.addEventListener('mousedown', handleMouseDown)
    }, 0)

    return () => {
      clearTimeout(timer)
      document.removeEventListener('mousedown', handleMouseDown)
    }
  }, [isOpen, onClose])

  // Reset expanded group when menu closes
  useEffect(() => {
    if (!isOpen) {
      setExpandedGroupId(null)
      setExpandedProgramGroupId(null)
    }
  }, [isOpen])

  if (!shouldRender) return null

  const handleLaunch = async (item: {
    path: string
    id: string
    name: string
    icon: string
    workingDir: string
  }): Promise<void> => {
    sounds.menuClick()
    try {
      const result = await window.electronAPI.program.launch(item)
      if (!result.success) {
        console.error('Failed to launch program:', result.error)
      }
      if (settings.minimizeOnUse) {
        window.electronAPI.window.minimize()
      }
    } catch (error) {
      console.error('Failed to launch program:', error)
    }
    onClose()
  }

  const handleOpenFolder = (groupId: string): void => {
    updateGroupWindowState(groupId, { minimized: false })
    openWindow(groupId)
    onClose()
  }

  const handleNewGroup = (): void => {
    sounds.menuClick()
    openDialog('newGroup')
    onClose()
  }

  const handleNewItem = (): void => {
    sounds.menuClick()
    const targetGroupId = activeWindowId || groups[0]?.id
    if (targetGroupId) {
      openDialog('newItem', { groupId: targetGroupId })
    } else {
      openDialog('newGroup', { openItemAfterCreate: true })
    }
    onClose()
  }

  const handleNewUrl = (): void => {
    sounds.menuClick()
    const targetGroupId = activeWindowId || groups[0]?.id
    if (targetGroupId) {
      openDialog('newUrl', { groupId: targetGroupId })
    } else {
      openDialog('newGroup', { openUrlAfterCreate: true })
    }
    onClose()
  }

  const handleLaunchGroups = async (): Promise<void> => {
    const buckets = collectLaunchGroups(groups)
    if (buckets.length === 0) return

    sounds.buttonClick()
    beginLaunchFeedback(
      buckets.length,
      buckets.reduce((count, bucket) => count + bucket.items.length, 0)
    )
    onClose()

    try {
      const results = await launchGroupBuckets(
        buckets,
        settings.launchDelay,
        ({ groupNumber, groupIndex }) => {
          sounds.menuClick()
          updateLaunchFeedback(groupNumber, groupIndex)
        }
      )
      const failures = results.filter((result) => !result.success)
      finishLaunchFeedback(failures.length)
      if (failures.length > 0) {
        console.error('Failed to launch some items:', failures)
      }
      if (settings.minimizeOnUse) {
        window.electronAPI.window.minimize()
      }
    } catch (error) {
      finishLaunchFeedback(1)
      console.error('Failed to launch items:', error)
    }
  }

  return (
    <div ref={menuRef} className={`win95-start-menu ${animClass === 'open' ? 'anim-start-menu-open' : animClass === 'closing' ? 'anim-start-menu-close' : ''}`}>
      {/* Vertical strip */}
      <div className="win95-start-menu-strip">
        <span className="win95-start-menu-strip-text">
          <span className="brand-accent">Gosh</span>95
        </span>
      </div>

      {/* Menu content */}
      <div className="win95-start-menu-content">
        <div
          className="win95-start-menu-item"
          onMouseEnter={() => {
            setExpandedGroupId('programs')
            setExpandedProgramGroupId(null)
          }}
        >
          <img
            src={getIconSrc('folder')}
            alt=""
            className="win95-start-menu-item-icon"
            draggable={false}
          />
          <span className="win95-start-menu-item-label">Programs</span>
          <span className="win95-start-menu-item-arrow">&#9658;</span>

          {expandedGroupId === 'programs' && (
            <div className="win95-start-submenu win95-programs-submenu">
              {groups.map((group) => (
                <div
                  key={group.id}
                  className="win95-start-submenu-item has-submenu"
                  onMouseEnter={() => setExpandedProgramGroupId(group.id)}
                >
                  <img
                    src={getIconSrc(group.icon) || DEFAULT_FOLDER_ICON}
                    alt=""
                    className="win95-start-submenu-item-icon"
                    draggable={false}
                  />
                  <span>{group.name}</span>
                  <span className="win95-start-menu-item-arrow">&#9658;</span>

                  {expandedProgramGroupId === group.id && (
                    <div className="win95-start-submenu win95-program-group-submenu">
                      {group.items.map((item) => (
                        <div
                          key={item.id}
                          className="win95-start-submenu-item"
                          onClick={(e) => {
                            e.stopPropagation()
                            handleLaunch(item)
                          }}
                        >
                          <img
                            src={getIconSrc(item.icon)}
                            alt=""
                            className="win95-start-submenu-item-icon"
                            draggable={false}
                          />
                          <span>{item.name}</span>
                        </div>
                      ))}

                      {group.items.length > 0 && <div className="win95-start-menu-separator" />}

                      <div
                        className="win95-start-submenu-item"
                        onClick={(e) => {
                          e.stopPropagation()
                          handleOpenFolder(group.id)
                        }}
                      >
                        <img
                          src={getIconSrc('folder-open')}
                          alt=""
                          className="win95-start-submenu-item-icon"
                          draggable={false}
                        />
                        <span>Open</span>
                      </div>
                    </div>
                  )}
                </div>
              ))}

              {groups.length > 0 && <div className="win95-start-menu-separator" />}

              <div className="win95-start-submenu-item" onClick={handleNewGroup}>
                <img
                  src={getIconSrc('folder')}
                  alt=""
                  className="win95-start-submenu-item-icon"
                  draggable={false}
                />
                <span>New Folder...</span>
              </div>
            </div>
          )}
        </div>

        <div
          className="win95-start-menu-item"
          onMouseEnter={() => setExpandedGroupId('documents')}
        >
          <img
            src={getIconSrc('document')}
            alt=""
            className="win95-start-menu-item-icon"
            draggable={false}
          />
          <span className="win95-start-menu-item-label">Documents</span>
          <span className="win95-start-menu-item-arrow">&#9658;</span>
          {expandedGroupId === 'documents' && (
            <div className="win95-start-submenu">
              <div className="win95-start-submenu-item" onClick={handleNewItem}>
                <img
                  src={getIconSrc('default')}
                  alt=""
                  className="win95-start-submenu-item-icon"
                  draggable={false}
                />
                <span>New Program Item...</span>
              </div>
              <div className="win95-start-submenu-item" onClick={handleNewUrl}>
                <img
                  src={getIconSrc('web')}
                  alt=""
                  className="win95-start-submenu-item-icon"
                  draggable={false}
                />
                <span>New URL...</span>
              </div>
            </div>
          )}
        </div>

        <div
          className="win95-start-menu-item"
          onMouseEnter={() => setExpandedGroupId('settings')}
        >
          <img
            src={getIconSrc('settings')}
            alt=""
            className="win95-start-menu-item-icon"
            draggable={false}
          />
          <span className="win95-start-menu-item-label">Settings</span>
          <span className="win95-start-menu-item-arrow">&#9658;</span>
          {expandedGroupId === 'settings' && (
            <div className="win95-start-submenu">
              <div
                className="win95-start-submenu-item"
                onClick={() => {
                  openDialog('settings')
                  onClose()
                }}
              >
                <img
                  src={getIconSrc('settings')}
                  alt=""
                  className="win95-start-submenu-item-icon"
                  draggable={false}
                />
                <span>Control Panel...</span>
              </div>
              <div
                className="win95-start-submenu-item"
                onClick={() => {
                  openDialog('settings')
                  onClose()
                }}
              >
                <img
                  src={getIconSrc('folder')}
                  alt=""
                  className="win95-start-submenu-item-icon"
                  draggable={false}
                />
                <span>Taskbar...</span>
              </div>
            </div>
          )}
        </div>

        <div className="win95-start-menu-separator" />

        <div
          className="win95-start-menu-item"
          onMouseEnter={() => setExpandedGroupId(null)}
          onClick={() => {
            openQuickSearch()
            onClose()
          }}
        >
          <img
            src={getIconSrc('search')}
            alt=""
            className="win95-start-menu-item-icon"
            draggable={false}
          />
          <span className="win95-start-menu-item-label">Find...</span>
        </div>

        <div
          className="win95-start-menu-item"
          onMouseEnter={() => setExpandedGroupId(null)}
          onClick={() => {
            openDialog('about')
            onClose()
          }}
        >
          <img
            src={getIconSrc('question')}
            alt=""
            className="win95-start-menu-item-icon"
            draggable={false}
          />
          <span className="win95-start-menu-item-label">Help</span>
        </div>

        <div
          className="win95-start-menu-item"
          onMouseEnter={() => setExpandedGroupId(null)}
          onClick={handleNewItem}
        >
          <img
            src={getIconSrc('terminal')}
            alt=""
            className="win95-start-menu-item-icon"
            draggable={false}
          />
          <span className="win95-start-menu-item-label">Run...</span>
        </div>

        <div className="win95-start-menu-separator" />

        {launchGroups.length > 0 && (
          <div
            className="win95-start-menu-item"
            onMouseEnter={() => setExpandedGroupId(null)}
            onClick={() => {
              handleLaunchGroups()
            }}
          >
            <img
              src={getIconSrc('default')}
              alt=""
              className="win95-start-menu-item-icon"
              draggable={false}
            />
            <span className="win95-start-menu-item-label">Launch Groups...</span>
          </div>
        )}

        {/* Shut Down */}
        <div
          className="win95-start-menu-item"
          onMouseEnter={() => setExpandedGroupId(null)}
          onClick={() => {
            window.electronAPI.window.quit()
          }}
        >
          <img
            src={getIconSrc('power')}
            alt=""
            className="win95-start-menu-item-icon"
            draggable={false}
          />
          <span className="win95-start-menu-item-label">Shut Down...</span>
        </div>
      </div>
    </div>
  )
}
