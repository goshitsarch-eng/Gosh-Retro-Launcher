import React, { useCallback, useRef } from 'react'
import { Menu } from './Menu'
import { MenuItem } from './MenuItem'
import { MenuSeparator } from './MenuSeparator'
import { useUIStore } from '@/store/uiStore'
import { useProgramStore } from '@/store/programStore'
import { useMDIStore } from '@/store/mdiStore'
import { useSounds } from '@/hooks/useSounds'
import { collectLaunchGroups, launchGroupBuckets } from '@/utils/launchGroups'

interface MenuBarProps {
  platform?: string
}

const MENU_ORDER = ['File', 'Options', 'Window', 'Help'] as const

export const MenuBar: React.FC<MenuBarProps> = ({ platform = 'linux' }) => {
  const activeMenu = useUIStore((state) => state.activeMenu)
  const setActiveMenu = useUIStore((state) => state.setActiveMenu)
  const openDialog = useUIStore((state) => state.openDialog)
  const openQuickSearch = useUIStore((state) => state.openQuickSearch)
  const beginLaunchFeedback = useUIStore((state) => state.beginLaunchFeedback)
  const updateLaunchFeedback = useUIStore((state) => state.updateLaunchFeedback)
  const finishLaunchFeedback = useUIStore((state) => state.finishLaunchFeedback)
  const selectedItemId = useUIStore((state) => state.selectedItemId)
  const selectedGroupId = useUIStore((state) => state.selectedGroupId)
  const groups = useProgramStore((state) => state.groups)
  const settings = useProgramStore((state) => state.settings)
  const updateSettings = useProgramStore((state) => state.updateSettings)
  const addItem = useProgramStore((state) => state.addItem)
  const deleteItem = useProgramStore((state) => state.deleteItem)
  const cascadeWindows = useMDIStore((state) => state.cascadeWindows)
  const tileWindows = useMDIStore((state) => state.tileWindows)
  const arrangeIcons = useMDIStore((state) => state.arrangeIcons)
  const focusWindow = useMDIStore((state) => state.focusWindow)
  const activeWindowId = useMDIStore((state) => state.activeWindowId)
  const sounds = useSounds()
  const launchInProgressRef = useRef(false)
  const launchGroups = collectLaunchGroups(groups)
  const hasLaunchItems = launchGroups.length > 0
  const selectedGroup = groups.find((group) => group.id === selectedGroupId)
  const selectedItem = selectedGroup?.items.find((item) => item.id === selectedItemId)

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

  const selectAdjacentMenu = useCallback((menuName: string, direction: -1 | 1) => {
    const currentIndex = MENU_ORDER.indexOf(menuName as (typeof MENU_ORDER)[number])
    const nextIndex = (currentIndex + direction + MENU_ORDER.length) % MENU_ORDER.length
    setActiveMenu(MENU_ORDER[nextIndex])
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

  const handleOpenSelected = useCallback(async () => {
    closeMenu()
    if (!selectedItem) return
    try {
      const result = await window.electronAPI.program.launch(selectedItem)
      if (!result.success) console.error('Failed to launch program:', result.error)
      if (settings.minimizeOnUse) void window.electronAPI.window.minimize()
    } catch (error) {
      console.error('Failed to launch program:', error)
    }
  }, [closeMenu, selectedItem, settings.minimizeOnUse])

  const handleSelectedProperties = useCallback(() => {
    closeMenu()
    if (selectedItem && selectedGroupId) {
      openDialog('itemProperties', { groupId: selectedGroupId, item: selectedItem })
    }
  }, [closeMenu, selectedItem, selectedGroupId, openDialog])

  const handleCopySelected = useCallback(() => {
    closeMenu()
    if (!selectedItem || !selectedGroupId) return
    addItem(selectedGroupId, {
      name: `Copy of ${selectedItem.name}`,
      path: selectedItem.path,
      icon: selectedItem.icon,
      workingDir: selectedItem.workingDir,
      launchGroup: selectedItem.launchGroup
    })
  }, [closeMenu, selectedItem, selectedGroupId, addItem])

  const handleDeleteSelected = useCallback(() => {
    closeMenu()
    if (!selectedItem || !selectedGroupId) return
    openDialog('confirm', {
      confirmOptions: {
        title: 'Delete Program Item',
        message: `Are you sure you want to delete "${selectedItem.name}"?`,
        onConfirm: () => deleteItem(selectedGroupId, selectedItem.id)
      }
    })
  }, [closeMenu, selectedItem, selectedGroupId, openDialog, deleteItem])

  const handleLaunchAll = useCallback(async () => {
    if (launchInProgressRef.current) return
    const buckets = collectLaunchGroups(groups)

    // Close first, then wait for a frame so the selected command visibly dismisses
    // before audio, progress updates, or IPC work can occupy the event turn.
    closeMenu()
    await new Promise<void>((resolve) => window.requestAnimationFrame(() => resolve()))
    if (buckets.length === 0) return

    launchInProgressRef.current = true
    sounds.buttonClick()
    beginLaunchFeedback(
      buckets.length,
      buckets.reduce((count, bucket) => count + bucket.items.length, 0)
    )

    try {
      const results = await launchGroupBuckets(
        buckets,
        settings.launchDelay,
        ({ groupNumber, groupIndex }) => {
          sounds.menuClick()
          updateLaunchFeedback(groupNumber, groupIndex)
        }
      )
      const failures = results.flat().filter((result) => !result.success)
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
    } finally {
      launchInProgressRef.current = false
    }
  }, [
    groups,
    settings.launchDelay,
    closeMenu,
    sounds,
    beginLaunchFeedback,
    updateLaunchFeedback,
    finishLaunchFeedback,
    settings.minimizeOnUse
  ])

  const handleExit = useCallback(() => {
    window.electronAPI.window.quit()
  }, [])

  const handleExport = useCallback(async () => {
    closeMenu()
    try {
      await window.electronAPI.store.exportData()
    } catch (error) {
      console.error('Failed to export:', error)
    }
  }, [closeMenu])

  const handleImport = useCallback(async () => {
    closeMenu()
    try {
      const result = await window.electronAPI.store.importData()
      if (result.success) {
        // Reload data
        useProgramStore.getState().loadData()
      }
    } catch (error) {
      console.error('Failed to import:', error)
    }
  }, [closeMenu])

  // Options menu actions
  const handleToggleAutoArrange = useCallback(() => {
    updateSettings({ autoArrange: !settings.autoArrange })
    closeMenu()
  }, [settings.autoArrange, updateSettings, closeMenu])

  const handleToggleMinimizeOnUse = useCallback(() => {
    updateSettings({ minimizeOnUse: !settings.minimizeOnUse })
    closeMenu()
  }, [settings.minimizeOnUse, updateSettings, closeMenu])

  const handleToggleSaveOnExit = useCallback(() => {
    updateSettings({ saveSettingsOnExit: !settings.saveSettingsOnExit })
    closeMenu()
  }, [settings.saveSettingsOnExit, updateSettings, closeMenu])

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

  const handleQuickSearch = useCallback(() => {
    openQuickSearch()
    closeMenu()
  }, [openQuickSearch, closeMenu])

  return (
    <div className="win31-menubar">
      {/* File Menu */}
      <Menu
        label="File"
        hotkey="F"
        isOpen={activeMenu === 'File'}
        onClick={() => handleMenuClick('File')}
        onHover={() => handleMenuHover('File')}
        onPrevious={() => selectAdjacentMenu('File', -1)}
        onNext={() => selectAdjacentMenu('File', 1)}
      >
        <MenuItem
          label="New..."
          hotkey="N"
          hasSubmenu
          submenu={
            <>
              <MenuItem label="Program Group..." hotkey="G" onClick={handleNewGroup} />
              <MenuItem label="Program Item..." hotkey="P" onClick={handleNewItem} />
              <MenuItem label="URL..." hotkey="U" onClick={handleNewUrl} />
            </>
          }
        />
        <MenuItem label="Open" hotkey="O" shortcut="Enter" onClick={handleOpenSelected} disabled={!selectedItem} />
        <MenuItem label="Move..." hotkey="M" onClick={handleSelectedProperties} disabled={!selectedItem} />
        <MenuItem label="Copy..." hotkey="C" onClick={handleCopySelected} disabled={!selectedItem} />
        <MenuItem label="Delete" hotkey="D" shortcut="Del" onClick={handleDeleteSelected} disabled={!selectedItem} />
        <MenuItem label="Properties..." hotkey="P" onClick={handleSelectedProperties} disabled={!selectedItem} />
        <MenuSeparator />
        <MenuItem
          label="Launch Groups"
          hotkey="L"
          onClick={handleLaunchAll}
          disabled={!hasLaunchItems}
        />
        <MenuItem label="Run..." hotkey="R" onClick={handleNewItem} />
        <MenuSeparator />
        <MenuItem label="Import..." hotkey="I" onClick={handleImport} />
        <MenuItem label="Export..." hotkey="E" onClick={handleExport} />
        <MenuItem label="Settings..." hotkey="S" onClick={handleSettings} />
        <MenuSeparator />
        <MenuItem label="Exit Program Manager" hotkey="x" onClick={handleExit} />
      </Menu>

      {/* Options Menu */}
      <Menu
        label="Options"
        hotkey="O"
        isOpen={activeMenu === 'Options'}
        onClick={() => handleMenuClick('Options')}
        onHover={() => handleMenuHover('Options')}
        onPrevious={() => selectAdjacentMenu('Options', -1)}
        onNext={() => selectAdjacentMenu('Options', 1)}
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
        onPrevious={() => selectAdjacentMenu('Window', -1)}
        onNext={() => selectAdjacentMenu('Window', 1)}
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
        onPrevious={() => selectAdjacentMenu('Help', -1)}
        onNext={() => selectAdjacentMenu('Help', 1)}
      >
        <MenuItem label="Contents" hotkey="C" disabled />
        <MenuItem
          label="Search for Help on..."
          hotkey="S"
          shortcut={platform === 'darwin' ? 'Cmd+Shift+Space' : 'Ctrl+Shift+Space'}
          onClick={handleQuickSearch}
        />
        <MenuItem label="How to Use Help" hotkey="H" disabled />
        <MenuSeparator />
        <MenuItem
          label="About Program Manager..."
          hotkey="A"
          onClick={handleAbout}
        />
      </Menu>
    </div>
  )
}
