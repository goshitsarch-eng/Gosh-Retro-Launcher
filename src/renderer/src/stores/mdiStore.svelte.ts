interface MDIWindowState {
  id: string
  groupId: string
  zIndex: number
}

// Reactive state using Svelte 5 runes
let windows = $state<MDIWindowState[]>([])
let activeWindowId = $state<string | null>(null)
let nextZIndex = $state(1)

export const mdiStore = {
  get windows() { return windows },
  get activeWindowId() { return activeWindowId },
  get nextZIndex() { return nextZIndex },

  openWindow(groupId: string) {
    const existing = windows.find((w) => w.groupId === groupId)

    if (existing) {
      // Focus existing window
      mdiStore.focusWindow(groupId)
    } else {
      // Open new window
      windows = [
        ...windows,
        { id: groupId, groupId, zIndex: nextZIndex }
      ]
      activeWindowId = groupId
      nextZIndex = nextZIndex + 1
    }
  },

  closeWindow(groupId: string) {
    const newWindows = windows.filter((w) => w.groupId !== groupId)

    windows = newWindows
    if (activeWindowId === groupId) {
      activeWindowId = newWindows.length > 0
        ? newWindows[newWindows.length - 1].groupId
        : null
    }
  },

  focusWindow(groupId: string) {
    windows = windows.map((w) =>
      w.groupId === groupId ? { ...w, zIndex: nextZIndex } : w
    )
    activeWindowId = groupId
    nextZIndex = nextZIndex + 1
  },

  setActiveWindow(groupId: string | null) {
    activeWindowId = groupId
  },

  cascadeWindows() {
    window.dispatchEvent(new CustomEvent('mdi-cascade'))
  },

  tileWindows() {
    window.dispatchEvent(new CustomEvent('mdi-tile'))
  },

  arrangeIcons() {
    window.dispatchEvent(new CustomEvent('mdi-arrange-icons'))
  }
}
