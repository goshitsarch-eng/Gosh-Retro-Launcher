<script lang="ts">
  import MDIWindow from './MDIWindow.svelte'
  import { programStore, mdiStore, uiStore } from '@/stores'
  import { getIconSrc } from '@/utils/icons'
  import type { ProgramGroup } from '@shared/types'

  let containerRef: HTMLDivElement | undefined = $state()
  let contextMenuRef: HTMLDivElement | undefined = $state()

  let groups = $derived(programStore.groups)
  let windows = $derived(mdiStore.windows)
  let activeWindowId = $derived(mdiStore.activeWindowId)

  let contextMenu = $state<{
    x: number
    y: number
    group: ProgramGroup
  } | null>(null)

  // Open windows for all groups - runs when groups change
  $effect(() => {
    groups.forEach((group) => {
      // Check if window already exists in MDI store
      const windowExists = windows.some((w) => w.groupId === group.id)
      if (!windowExists && !group.windowState.minimized) {
        mdiStore.openWindow(group.id)
      }
    })
  })

  // Handle cascade windows event
  function handleCascade() {
    groups.forEach((group, index) => {
      programStore.updateGroupWindowState(group.id, {
        x: 20 + index * 30,
        y: 20 + index * 30,
        width: 300,
        height: 200,
        minimized: false,
        maximized: false
      })
    })
  }

  // Handle tile windows event
  function handleTile() {
    if (!containerRef) return

    const visibleGroups = groups.filter((g) => !g.windowState.minimized)
    const count = visibleGroups.length
    if (count === 0) return

    const containerRect = containerRef.getBoundingClientRect()
    const cols = Math.ceil(Math.sqrt(count))
    const rows = Math.ceil(count / cols)
    const width = Math.floor(containerRect.width / cols)
    const height = Math.floor(containerRect.height / rows)

    visibleGroups.forEach((group, index) => {
      const col = index % cols
      const row = Math.floor(index / cols)
      programStore.updateGroupWindowState(group.id, {
        x: col * width,
        y: row * height,
        width,
        height,
        minimized: false,
        maximized: false
      })
    })
  }

  // Handle arrange icons event
  function handleArrangeIcons() {
    const minimizedGroups = groups.filter((g) => g.windowState.minimized)
    minimizedGroups.forEach((group, index) => {
      programStore.updateGroupWindowState(group.id, {
        x: 10 + (index % 8) * 75,
        y: 10 + Math.floor(index / 8) * 75
      })
    })
  }

  // Listen for window arrangement events
  $effect(() => {
    window.addEventListener('mdi-cascade', handleCascade)
    window.addEventListener('mdi-tile', handleTile)
    window.addEventListener('mdi-arrange-icons', handleArrangeIcons)

    return () => {
      window.removeEventListener('mdi-cascade', handleCascade)
      window.removeEventListener('mdi-tile', handleTile)
      window.removeEventListener('mdi-arrange-icons', handleArrangeIcons)
    }
  })

  // Handle Delete key for active group (when no item is selected)
  $effect(() => {
    function handleDeleteKey(event: KeyboardEvent) {
      // Only handle Delete if no item is selected and no dialog is open
      if (event.key === 'Delete' && !uiStore.selectedItemId && activeWindowId && !uiStore.activeDialog) {
        const group = groups.find(g => g.id === activeWindowId)
        if (group) {
          confirmDeleteGroup(group)
        }
      }
    }

    window.addEventListener('keydown', handleDeleteKey)
    return () => window.removeEventListener('keydown', handleDeleteKey)
  })

  // Close context menu on click/escape
  $effect(() => {
    if (!contextMenu) return

    const handleClick = () => contextMenu = null
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        contextMenu = null
      }
    }

    window.addEventListener('click', handleClick)
    window.addEventListener('contextmenu', handleClick)
    window.addEventListener('keydown', handleKeyDown)

    return () => {
      window.removeEventListener('click', handleClick)
      window.removeEventListener('contextmenu', handleClick)
      window.removeEventListener('keydown', handleKeyDown)
    }
  })

  // Adjust context menu position to stay within viewport
  $effect(() => {
    if (!contextMenu || !contextMenuRef) return

    const menuRect = contextMenuRef.getBoundingClientRect()
    const padding = 4
    let x = contextMenu.x
    let y = contextMenu.y

    x = Math.max(padding, Math.min(x, window.innerWidth - menuRect.width - padding))
    y = Math.max(padding, Math.min(y, window.innerHeight - menuRect.height - padding))

    if (x !== contextMenu.x || y !== contextMenu.y) {
      contextMenu = { ...contextMenu, x, y }
    }
  })

  // Get visible and minimized groups
  let visibleGroups = $derived(groups.filter((g) => !g.windowState.minimized))
  let minimizedGroups = $derived(groups.filter((g) => g.windowState.minimized))

  // Get z-index for a window
  function getZIndex(groupId: string): number {
    const window = windows.find((w) => w.groupId === groupId)
    return window?.zIndex ?? 0
  }

  function restoreGroup(group: ProgramGroup) {
    programStore.updateGroupWindowState(group.id, { minimized: false })
    mdiStore.focusWindow(group.id)
  }

  function confirmDeleteGroup(group: ProgramGroup) {
    uiStore.openDialog('confirm', {
      confirmOptions: {
        title: 'Delete Group',
        message: `Are you sure you want to delete "${group.name}" and all its items?`,
        onConfirm: () => {
          mdiStore.closeWindow(group.id)
          programStore.deleteGroup(group.id)
        }
      }
    })
  }

  function handleContainerClick() {
    if (contextMenu) {
      contextMenu = null
    }
  }

  function handleIconContextMenu(event: MouseEvent, group: ProgramGroup) {
    event.preventDefault()
    event.stopPropagation()
    contextMenu = {
      x: event.clientX,
      y: event.clientY,
      group
    }
  }
</script>

<div
  bind:this={containerRef}
  class="win31-mdi-container"
  onclick={handleContainerClick}
  role="main"
>
  <!-- Visible windows -->
  {#each visibleGroups as group (group.id)}
    <MDIWindow
      {group}
      isActive={activeWindowId === group.id}
      zIndex={getZIndex(group.id)}
      getContainerRef={() => containerRef}
      onFocus={() => mdiStore.focusWindow(group.id)}
    />
  {/each}

  <!-- Minimized icons at bottom -->
  {#if minimizedGroups.length > 0}
    <div class="win31-mdi-icon-bar">
      {#each minimizedGroups as group (group.id)}
        <div
          class="win31-mdi-icon"
          ondblclick={() => restoreGroup(group)}
          oncontextmenu={(e) => handleIconContextMenu(e, group)}
          role="button"
          tabindex="0"
        >
          <img
            src={getIconSrc(group.icon)}
            alt={group.name}
            class="icon"
            draggable="false"
          />
          <span class="label">{group.name}</span>
        </div>
      {/each}
    </div>
  {/if}

  {#if contextMenu}
    <div
      bind:this={contextMenuRef}
      class="win31-context-menu"
      style="left: {contextMenu.x}px; top: {contextMenu.y}px;"
      onclick={(e) => e.stopPropagation()}
      oncontextmenu={(e) => e.preventDefault()}
      role="menu"
    >
      <div
        class="win31-menu-item"
        onclick={() => {
          if (contextMenu) restoreGroup(contextMenu.group)
          contextMenu = null
        }}
        role="menuitem"
      >
        Open
      </div>
      <div class="win31-menu-separator"></div>
      <div
        class="win31-menu-item"
        onclick={() => {
          if (contextMenu) uiStore.openDialog('renameGroup', { group: contextMenu.group })
          contextMenu = null
        }}
        role="menuitem"
      >
        Rename...
      </div>
      <div
        class="win31-menu-item"
        onclick={() => {
          if (contextMenu) {
            uiStore.openDialog('groupProperties', {
              group: contextMenu.group,
              showIconPicker: true
            })
          }
          contextMenu = null
        }}
        role="menuitem"
      >
        Change Icon...
      </div>
      <div
        class="win31-menu-item"
        onclick={() => {
          if (contextMenu) uiStore.openDialog('groupProperties', { group: contextMenu.group })
          contextMenu = null
        }}
        role="menuitem"
      >
        Properties...
      </div>
      <div class="win31-menu-separator"></div>
      <div
        class="win31-menu-item"
        onclick={() => {
          if (contextMenu) confirmDeleteGroup(contextMenu.group)
          contextMenu = null
        }}
        role="menuitem"
      >
        Delete
      </div>
    </div>
  {/if}
</div>
