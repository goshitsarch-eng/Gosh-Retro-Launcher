import React, { useCallback } from 'react'
import { Menu } from './Menu'
import { MenuItem } from './MenuItem'
import { MenuSeparator } from './MenuSeparator'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import type { ProgramItem } from '@shared/types'

export const MenuBar: React.FC = () => {
  const { activeMenu, setActiveMenu, openDialog } = useUIStore()
  const { groups, settings, updateSettings } = useProgramStore()
  const {
    cascadeWindows,
    tileWindows,
    arrangeIcons,
    focusWindow,
    activeWindowId
  } = useMDIStore()
  const hasLaunchItems = groups.some((group) =>
    group.items.some((item) => (item.launchGroup ?? 0) > 0)
  )

  const handleMenuClick = useCallback(
    (menuName: string) => {
      setActiveMenu(activeMenu === menuName ? null : menuName)
    },
    [activeMenu, setActiveMenu]
  )

  const handleMenuHover = useCallback(
    (menuName: string) => {
      if (activeMenu !== null) {
        setActiveMenu(menuName)
      }
    },
    [activeMenu, setActiveMenu]
  )

  const closeMenu = useCallback(() => {
    setActiveMenu(null)
  }, [setActiveMenu])

  // File menu actions
  const handleNewGroup = useCallback(() => {
    openDialog('newGroup')
    closeMenu()
  }, [openDialog, closeMenu])

  const handleNewItem = useCallback(() => {
    const targetGroupId = activeWindowId || groups[0]?.id
    if (!targetGroupId) {
      openDialog('newGroup', { openItemAfterCreate: true })
      closeMenu()
      return
    }
    openDialog('newItem', { groupId: targetGroupId })
    closeMenu()
  }, [activeWindowId, groups, openDialog, closeMenu])

  const handleNewUrl = useCallback(() => {
    const targetGroupId = activeWindowId || groups[0]?.id
    if (!targetGroupId) {
      openDialog('newGroup', { openUrlAfterCreate: true })
      closeMenu()
      return
    }
    openDialog('newUrl', { groupId: targetGroupId })
    closeMenu()
  }, [activeWindowId, groups, openDialog, closeMenu])

  const handleLaunchAll = useCallback(async () => {
    const launchGroups = new Map<number, ProgramItem[]>()

    for (const group of groups) {
      for (const item of group.items) {
        const launchGroup = item.launchGroup ?? 0
        if (launchGroup <= 0) continue
        const bucket = launchGroups.get(launchGroup) ?? []
        bucket.push(item)
        launchGroups.set(launchGroup, bucket)
      }
    }

    if (launchGroups.size === 0) {
      closeMenu()
      return
    }

    try {
      const results = await Promise.all(
        Array.from(launchGroups.entries())
          .sort(([a], [b]) => a - b)
          .map(([_, items]) =>
            window.electronAPI.program.launchBatch(items, settings.launchDelay)
          )
      )
      const failures = results.flat().filter((result) => !result.success)
      if (failures.length > 0) {
        console.error('Failed to launch some items:', failures)
      }
    } catch (error) {
      console.error('Failed to launch items:', error)
    } finally {
      closeMenu()
    }
  }, [groups, settings.launchDelay, closeMenu])

  const handleExit = useCallback(() => {
    window.electronAPI.window.quit()
  }, [])

  const handleExport = useCallback(async () => {
    try {
      await window.electronAPI.store.exportData()
    } catch (error) {
      console.error('Failed to export:', error)
    }
    closeMenu()
  }, [closeMenu])

  const handleImport = useCallback(async () => {
    try {
      const result = await window.electronAPI.store.importData()
      if (result.success) {
        // Reload data
        useProgramStore.getState().loadData()
      }
    } catch (error) {
      console.error('Failed to import:', error)
    }
    closeMenu()
  }, [closeMenu])

  // Options menu actions
  const handleToggleAutoArrange = useCallback(() => {
    updateSettings({ autoArrange: !settings.autoArrange })
  }, [settings.autoArrange, updateSettings])

  const handleToggleMinimizeOnUse = useCallback(() => {
    updateSettings({ minimizeOnUse: !settings.minimizeOnUse })
  }, [settings.minimizeOnUse, updateSettings])

  const handleToggleSaveOnExit = useCallback(() => {
    updateSettings({ saveSettingsOnExit: !settings.saveSettingsOnExit })
  }, [settings.saveSettingsOnExit, updateSettings])

  // Window menu actions
  const handleCascade = useCallback(() => {
    cascadeWindows()
    closeMenu()
  }, [cascadeWindows, closeMenu])

  const handleTile = useCallback(() => {
    tileWindows()
    closeMenu()
  }, [tileWindows, closeMenu])

  const handleArrangeIcons = useCallback(() => {
    arrangeIcons()
    closeMenu()
  }, [arrangeIcons, closeMenu])

  const handleSelectWindow = useCallback(
    (groupId: string) => {
      focusWindow(groupId)
      closeMenu()
    },
    [focusWindow, closeMenu]
  )

  // Help menu actions
  const handleAbout = useCallback(() => {
    openDialog('about')
    closeMenu()
  }, [openDialog, closeMenu])

  const handleSettings = useCallback(() => {
    openDialog('settings')
    closeMenu()
  }, [openDialog, closeMenu])

  return (
    <div className="win31-menubar">
      {/* File Menu */}
      <Menu
        label="File"
        hotkey="F"
        isOpen={activeMenu === 'File'}
        onClick={() => handleMenuClick('File')}
        onHover={() => handleMenuHover('File')}
      >
        <MenuItem
          label="New"
          hotkey="N"
          hasSubmenu
          submenu={
            <>
              <MenuItem label="Program Group..." onClick={handleNewGroup} />
              <MenuItem label="Program Item..." onClick={handleNewItem} />
              <MenuItem label="URL..." onClick={handleNewUrl} />
            </>
          }
        />
        <MenuItem
          label="Launch All"
          hotkey="L"
          onClick={handleLaunchAll}
          disabled={!hasLaunchItems}
        />
        <MenuSeparator />
        <MenuItem label="Import..." onClick={handleImport} />
        <MenuItem label="Export..." onClick={handleExport} />
        <MenuSeparator />
        <MenuItem label="Settings..." onClick={handleSettings} />
        <MenuSeparator />
        <MenuItem label="Exit" hotkey="x" onClick={handleExit} />
      </Menu>

      {/* Options Menu */}
      <Menu
        label="Options"
        hotkey="O"
        isOpen={activeMenu === 'Options'}
        onClick={() => handleMenuClick('Options')}
        onHover={() => handleMenuHover('Options')}
      >
        <MenuItem
          label="Auto Arrange"
          checkbox
          checked={settings.autoArrange}
          onClick={handleToggleAutoArrange}
        />
        <MenuItem
          label="Minimize on Use"
          checkbox
          checked={settings.minimizeOnUse}
          onClick={handleToggleMinimizeOnUse}
        />
        <MenuItem
          label="Save Settings on Exit"
          checkbox
          checked={settings.saveSettingsOnExit}
          onClick={handleToggleSaveOnExit}
        />
      </Menu>

      {/* Window Menu */}
      <Menu
        label="Window"
        hotkey="W"
        isOpen={activeMenu === 'Window'}
        onClick={() => handleMenuClick('Window')}
        onHover={() => handleMenuHover('Window')}
      >
        <MenuItem
          label="Cascade"
          shortcut="Shift+F5"
          onClick={handleCascade}
        />
        <MenuItem
          label="Tile"
          shortcut="Shift+F4"
          onClick={handleTile}
        />
        <MenuItem label="Arrange Icons" onClick={handleArrangeIcons} />
        {groups.length > 0 && (
          <>
            <MenuSeparator />
            {groups.map((group) => (
              <MenuItem
                key={group.id}
                label={group.name}
                onClick={() => handleSelectWindow(group.id)}
              />
            ))}
          </>
        )}
      </Menu>

      {/* Help Menu */}
      <Menu
        label="Help"
        hotkey="H"
        isOpen={activeMenu === 'Help'}
        onClick={() => handleMenuClick('Help')}
        onHover={() => handleMenuHover('Help')}
      >
        <MenuItem
          label="About Program Manager..."
          onClick={handleAbout}
        />
      </Menu>
    </div>
  )
}
