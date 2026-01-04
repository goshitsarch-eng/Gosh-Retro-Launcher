<script lang="ts">
  import Menu from './Menu.svelte'
  import MenuItem from './MenuItem.svelte'
  import MenuSeparator from './MenuSeparator.svelte'
  import { uiStore, programStore, mdiStore } from '@/stores'
  import type { ProgramItem } from '@shared/types'

  let groups = $derived(programStore.groups)
  let settings = $derived(programStore.settings)
  let activeMenu = $derived(uiStore.activeMenu)
  let activeWindowId = $derived(mdiStore.activeWindowId)

  let hasLaunchItems = $derived(
    groups.some((group) => group.items.some((item) => (item.launchGroup ?? 0) > 0))
  )

  function handleMenuClick(menuName: string) {
    uiStore.setActiveMenu(activeMenu === menuName ? null : menuName)
  }

  function handleMenuHover(menuName: string) {
    if (activeMenu !== null) {
      uiStore.setActiveMenu(menuName)
    }
  }

  function closeMenu() {
    uiStore.setActiveMenu(null)
  }

  // File menu actions
  function handleNewGroup() {
    uiStore.openDialog('newGroup')
    closeMenu()
  }

  function handleNewItem() {
    const targetGroupId = activeWindowId || groups[0]?.id
    if (!targetGroupId) {
      uiStore.openDialog('newGroup', { openItemAfterCreate: true })
      closeMenu()
      return
    }
    uiStore.openDialog('newItem', { groupId: targetGroupId })
    closeMenu()
  }

  function handleNewUrl() {
    const targetGroupId = activeWindowId || groups[0]?.id
    if (!targetGroupId) {
      uiStore.openDialog('newGroup', { openUrlAfterCreate: true })
      closeMenu()
      return
    }
    uiStore.openDialog('newUrl', { groupId: targetGroupId })
    closeMenu()
  }

  async function handleLaunchAll() {
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
  }

  function handleExit() {
    window.electronAPI.window.quit()
  }

  async function handleExport() {
    await window.electronAPI.store.exportData()
    closeMenu()
  }

  async function handleImport() {
    const result = await window.electronAPI.store.importData()
    if (result.success) {
      // Reload data
      programStore.loadData()
    }
    closeMenu()
  }

  // Options menu actions
  function handleToggleAutoArrange() {
    programStore.updateSettings({ autoArrange: !settings.autoArrange })
  }

  function handleToggleMinimizeOnUse() {
    programStore.updateSettings({ minimizeOnUse: !settings.minimizeOnUse })
  }

  function handleToggleSaveOnExit() {
    programStore.updateSettings({ saveSettingsOnExit: !settings.saveSettingsOnExit })
  }

  // Window menu actions
  function handleCascade() {
    mdiStore.cascadeWindows()
    closeMenu()
  }

  function handleTile() {
    mdiStore.tileWindows()
    closeMenu()
  }

  function handleArrangeIcons() {
    mdiStore.arrangeIcons()
    closeMenu()
  }

  function handleSelectWindow(groupId: string) {
    mdiStore.focusWindow(groupId)
    closeMenu()
  }

  // Help menu actions
  function handleAbout() {
    uiStore.openDialog('about')
    closeMenu()
  }

  function handleSettings() {
    uiStore.openDialog('settings')
    closeMenu()
  }
</script>

<div class="win31-menubar">
  <!-- File Menu -->
  <Menu
    label="File"
    hotkey="F"
    isOpen={activeMenu === 'File'}
    onClick={() => handleMenuClick('File')}
    onHover={() => handleMenuHover('File')}
  >
    {#snippet children()}
      <MenuItem
        label="New"
        hotkey="N"
        hasSubmenu
      >
        {#snippet submenu()}
          <MenuItem label="Program Group..." onClick={handleNewGroup} />
          <MenuItem label="Program Item..." onClick={handleNewItem} />
          <MenuItem label="URL..." onClick={handleNewUrl} />
        {/snippet}
      </MenuItem>
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
    {/snippet}
  </Menu>

  <!-- Options Menu -->
  <Menu
    label="Options"
    hotkey="O"
    isOpen={activeMenu === 'Options'}
    onClick={() => handleMenuClick('Options')}
    onHover={() => handleMenuHover('Options')}
  >
    {#snippet children()}
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
    {/snippet}
  </Menu>

  <!-- Window Menu -->
  <Menu
    label="Window"
    hotkey="W"
    isOpen={activeMenu === 'Window'}
    onClick={() => handleMenuClick('Window')}
    onHover={() => handleMenuHover('Window')}
  >
    {#snippet children()}
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
      {#if groups.length > 0}
        <MenuSeparator />
        {#each groups as group (group.id)}
          <MenuItem
            label={group.name}
            onClick={() => handleSelectWindow(group.id)}
          />
        {/each}
      {/if}
    {/snippet}
  </Menu>

  <!-- Help Menu -->
  <Menu
    label="Help"
    hotkey="H"
    isOpen={activeMenu === 'Help'}
    onClick={() => handleMenuClick('Help')}
    onHover={() => handleMenuHover('Help')}
  >
    {#snippet children()}
      <MenuItem
        label="About Gosh Retro Launcher..."
        onClick={handleAbout}
      />
    {/snippet}
  </Menu>
</div>
