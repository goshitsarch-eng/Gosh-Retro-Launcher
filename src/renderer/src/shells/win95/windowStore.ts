import { create } from 'zustand'
import { getGroupWindowState, type LogicalRect } from '@shared/types'
import { useProgramStore } from '../../store/programStore'

export type Win95WindowKind = 'my-computer' | 'group' | 'find'
export type Win95WindowCommand = 'move' | 'size'

export interface Win95WindowEntry {
  id: string
  kind: Win95WindowKind
  groupId?: string
  zIndex: number
  /** Used only by shell-owned system folders. Group geometry stays in programStore. */
  systemBounds?: LogicalRect
  systemRestoreBounds?: LogicalRect
  systemMinimized?: boolean
  systemMaximized?: boolean
}

interface Win95WindowState {
  windows: Win95WindowEntry[]
  activeWindowId: string | null
  nextZIndex: number
  requestedCommand: { id: string; command: Win95WindowCommand; nonce: number } | null
  openMyComputer: () => void
  openFind: () => void
  openGroup: (groupId: string) => void
  focusWindow: (id: string) => void
  closeWindow: (id: string) => void
  deactivateWindow: (id: string) => void
  activateDesktop: () => void
  updateSystemWindow: (id: string, updates: Partial<Win95WindowEntry>) => void
  requestWindowCommand: (id: string, command: Win95WindowCommand) => void
  clearWindowCommand: (nonce: number) => void
  reset: () => void
}

const MY_COMPUTER_DEFAULT: LogicalRect = { x: 42, y: 34, width: 430, height: 300 }
const FIND_DEFAULT: LogicalRect = { x: 96, y: 58, width: 439, height: 237 }

function entryIsMinimized(entry: Win95WindowEntry): boolean {
  if (entry.kind === 'group' && entry.groupId) {
    const group = useProgramStore.getState().groups.find((candidate) => candidate.id === entry.groupId)
    return group ? getGroupWindowState(group, 'win95').minimized : true
  }
  return !!entry.systemMinimized
}

function topVisibleWindow(windows: Win95WindowEntry[], excludedId?: string): string | null {
  return [...windows]
    .filter((entry) => entry.id !== excludedId && !entryIsMinimized(entry))
    .sort((a, b) => b.zIndex - a.zIndex)[0]?.id ?? null
}

function bringToFront(
  windows: Win95WindowEntry[],
  id: string,
  zIndex: number
): Win95WindowEntry[] {
  return windows.map((entry) => entry.id === id ? { ...entry, zIndex } : entry)
}

export const useWin95WindowStore = create<Win95WindowState>((set, get) => ({
  windows: [],
  activeWindowId: null,
  nextZIndex: 1,
  requestedCommand: null,
  openMyComputer: () => {
    const state = get()
    const existing = state.windows.find((entry) => entry.id === 'my-computer')
    if (existing) {
      set({
        windows: bringToFront(state.windows.map((entry) => entry.id === existing.id
          ? { ...entry, systemMinimized: false }
          : entry), existing.id, state.nextZIndex),
        activeWindowId: existing.id,
        nextZIndex: state.nextZIndex + 1
      })
      return
    }
    set({
      windows: [...state.windows, {
        id: 'my-computer',
        kind: 'my-computer',
        zIndex: state.nextZIndex,
        systemBounds: { ...MY_COMPUTER_DEFAULT },
        systemMinimized: false,
        systemMaximized: false
      }],
      activeWindowId: 'my-computer',
      nextZIndex: state.nextZIndex + 1
    })
  },
  openFind: () => {
    const state = get()
    const existing = state.windows.find((entry) => entry.id === 'find')
    if (existing) {
      set({
        windows: bringToFront(state.windows.map((entry) => entry.id === existing.id ? { ...entry, systemMinimized: false } : entry), existing.id, state.nextZIndex),
        activeWindowId: existing.id,
        nextZIndex: state.nextZIndex + 1
      })
      return
    }
    set({
      windows: [...state.windows, { id: 'find', kind: 'find', zIndex: state.nextZIndex, systemBounds: { ...FIND_DEFAULT }, systemMinimized: false, systemMaximized: false }],
      activeWindowId: 'find',
      nextZIndex: state.nextZIndex + 1
    })
  },
  openGroup: (groupId) => {
    useProgramStore.getState().updateGroupWindowState(groupId, { minimized: false }, 'win95')
    const state = get()
    const id = `group:${groupId}`
    const existing = state.windows.find((entry) => entry.id === id)
    if (existing) {
      set({
        windows: bringToFront(state.windows, id, state.nextZIndex),
        activeWindowId: id,
        nextZIndex: state.nextZIndex + 1
      })
      return
    }
    set({
      windows: [...state.windows, {
        id,
        kind: 'group',
        groupId,
        zIndex: state.nextZIndex
      }],
      activeWindowId: id,
      nextZIndex: state.nextZIndex + 1
    })
  },
  focusWindow: (id) => {
    const state = get()
    const target = state.windows.find((entry) => entry.id === id)
    if (!target || entryIsMinimized(target)) return
    set({
      windows: bringToFront(state.windows, id, state.nextZIndex),
      activeWindowId: id,
      nextZIndex: state.nextZIndex + 1
    })
  },
  closeWindow: (id) => {
    const state = get()
    const windows = state.windows.filter((entry) => entry.id !== id)
    const active = state.activeWindowId === id
      ? topVisibleWindow(windows)
      : state.activeWindowId
    set({ windows, activeWindowId: active })
  },
  deactivateWindow: (id) => set((state) => ({
    activeWindowId: state.activeWindowId === id ? topVisibleWindow(state.windows, id) : state.activeWindowId
  })),
  activateDesktop: () => set({ activeWindowId: null }),
  updateSystemWindow: (id, updates) => set((state) => ({
    windows: state.windows.map((entry) => entry.id === id ? { ...entry, ...updates } : entry)
  })),
  requestWindowCommand: (id, command) => set((state) => ({
    requestedCommand: { id, command, nonce: (state.requestedCommand?.nonce ?? 0) + 1 }
  })),
  clearWindowCommand: (nonce) => set((state) => state.requestedCommand?.nonce === nonce ? { requestedCommand: null } : {}),
  reset: () => set({ windows: [], activeWindowId: null, nextZIndex: 1, requestedCommand: null })
}))
