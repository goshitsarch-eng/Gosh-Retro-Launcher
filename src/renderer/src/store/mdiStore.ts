import { create } from 'zustand'

interface MDIWindowState {
  id: string
  groupId: string
  zIndex: number
}

interface MDIState {
  windows: MDIWindowState[]
  activeWindowId: string | null
  nextZIndex: number

  // Actions
  openWindow: (groupId: string) => void
  closeWindow: (groupId: string) => void
  focusWindow: (groupId: string) => void
  setActiveWindow: (groupId: string | null) => void

  // Window arrangement
  cascadeWindows: () => void
  tileWindows: () => void
  arrangeIcons: () => void
}

export const useMDIStore = create<MDIState>((set, get) => ({
  windows: [],
  activeWindowId: null,
  nextZIndex: 1,

  openWindow: (groupId: string) => {
    const { windows, nextZIndex } = get()
    const existing = windows.find((w) => w.groupId === groupId)

    if (existing) {
      // Focus existing window
      get().focusWindow(groupId)
    } else {
      // Open new window
      set({
        windows: [
          ...windows,
          { id: groupId, groupId, zIndex: nextZIndex }
        ],
        activeWindowId: groupId,
        nextZIndex: nextZIndex + 1
      })
    }
  },

  closeWindow: (groupId: string) => {
    const { windows, activeWindowId } = get()
    const newWindows = windows.filter((w) => w.groupId !== groupId)

    set({
      windows: newWindows,
      activeWindowId:
        activeWindowId === groupId
          ? newWindows.length > 0
            ? newWindows[newWindows.length - 1].groupId
            : null
          : activeWindowId
    })
  },

  focusWindow: (groupId: string) => {
    const { windows, nextZIndex } = get()
    set({
      windows: windows.map((w) =>
        w.groupId === groupId ? { ...w, zIndex: nextZIndex } : w
      ),
      activeWindowId: groupId,
      nextZIndex: nextZIndex + 1
    })
  },

  setActiveWindow: (groupId: string | null) => {
    set({ activeWindowId: groupId })
  },

  cascadeWindows: () => {
    // This will be handled by the MDIContainer component
    // by dispatching a custom event
    window.dispatchEvent(new CustomEvent('mdi-cascade'))
  },

  tileWindows: () => {
    window.dispatchEvent(new CustomEvent('mdi-tile'))
  },

  arrangeIcons: () => {
    window.dispatchEvent(new CustomEvent('mdi-arrange-icons'))
  }
}))
