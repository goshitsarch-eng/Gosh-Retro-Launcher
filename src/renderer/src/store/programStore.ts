import { create } from 'zustand'
import { v4 as uuidv4 } from 'uuid'
import type { ProgramGroup, ProgramItem, AppSettings, WindowState } from '@shared/types'
import { DEFAULT_SETTINGS, DEFAULT_WINDOW_STATE } from '@shared/types'

let saveGroupsTimer: ReturnType<typeof setTimeout> | null = null
let saveSettingsTimer: ReturnType<typeof setTimeout> | null = null
const itemNameCollator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' })

function sortProgramItems(items: ProgramItem[]): ProgramItem[] {
  return [...items].sort((a, b) => itemNameCollator.compare(a.name, b.name))
}

function debouncedSaveGroups(saveGroups: () => Promise<void>): void {
  if (saveGroupsTimer) clearTimeout(saveGroupsTimer)
  saveGroupsTimer = setTimeout(() => {
    saveGroupsTimer = null
    saveGroups()
  }, 300)
}

function debouncedSaveSettings(saveSettings: () => Promise<void>): void {
  if (saveSettingsTimer) clearTimeout(saveSettingsTimer)
  saveSettingsTimer = setTimeout(() => {
    saveSettingsTimer = null
    saveSettings()
  }, 300)
}

interface ProgramState {
  groups: ProgramGroup[]
  settings: AppSettings
  isLoading: boolean

  // Actions
  loadData: () => Promise<void>
  saveGroups: () => Promise<void>
  saveSettings: () => Promise<void>

  // Group actions
  addGroup: (name: string) => string
  updateGroup: (id: string, updates: Partial<ProgramGroup>) => void
  deleteGroup: (id: string) => void
  updateGroupWindowState: (id: string, windowState: Partial<WindowState>) => void

  // Item actions
  addItem: (groupId: string, item: Omit<ProgramItem, 'id'>) => void
  updateItem: (groupId: string, itemId: string, updates: Partial<ProgramItem>) => void
  deleteItem: (groupId: string, itemId: string) => void
  moveItem: (fromGroupId: string, toGroupId: string, itemId: string) => void

  // Settings actions
  updateSettings: (updates: Partial<AppSettings>) => void
}

export const useProgramStore = create<ProgramState>((set, get) => ({
  groups: [],
  settings: DEFAULT_SETTINGS,
  isLoading: true,

  loadData: async () => {
    try {
      const data = await window.electronAPI.store.getAll()
      set({
        groups: data.groups || [],
        settings: { ...DEFAULT_SETTINGS, ...data.settings },
        isLoading: false
      })
    } catch (error) {
      console.error('Failed to load data:', error)
      set({ isLoading: false })
    }
  },

  saveGroups: async () => {
    const { groups } = get()
    await window.electronAPI.store.set('groups', groups)
  },

  saveSettings: async () => {
    const { settings } = get()
    await window.electronAPI.store.set('settings', settings)
  },

  // Group actions
  addGroup: (name: string) => {
    const { groups, saveGroups } = get()
    const existingCount = groups.length

    const newGroup: ProgramGroup = {
      id: uuidv4(),
      name,
      icon: 'folder',
      windowState: {
        ...DEFAULT_WINDOW_STATE,
        x: DEFAULT_WINDOW_STATE.x + existingCount * 30,
        y: DEFAULT_WINDOW_STATE.y + existingCount * 30
      },
      items: []
    }

    set({ groups: [...groups, newGroup] })
    debouncedSaveGroups(saveGroups)
    return newGroup.id
  },

  updateGroup: (id: string, updates: Partial<ProgramGroup>) => {
    const { groups, saveGroups } = get()
    set({
      groups: groups.map((g) => (g.id === id ? { ...g, ...updates } : g))
    })
    debouncedSaveGroups(saveGroups)
  },

  deleteGroup: (id: string) => {
    const { groups, saveGroups } = get()
    set({ groups: groups.filter((g) => g.id !== id) })
    debouncedSaveGroups(saveGroups)
  },

  updateGroupWindowState: (id: string, windowState: Partial<WindowState>) => {
    const { groups, saveGroups, settings } = get()
    set({
      groups: groups.map((g) =>
        g.id === id ? { ...g, windowState: { ...g.windowState, ...windowState } } : g
      )
    })
    if (settings.saveSettingsOnExit) {
      debouncedSaveGroups(saveGroups)
    }
  },

  // Item actions
  addItem: (groupId: string, item: Omit<ProgramItem, 'id'>) => {
    const { groups, saveGroups, settings } = get()
    const newItem: ProgramItem = {
      ...item,
      id: uuidv4()
    }

    set({
      groups: groups.map((g) =>
        g.id === groupId
          ? {
              ...g,
              items: settings.autoArrange
                ? sortProgramItems([...g.items, newItem])
                : [...g.items, newItem]
            }
          : g
      )
    })
    debouncedSaveGroups(saveGroups)
  },

  updateItem: (groupId: string, itemId: string, updates: Partial<ProgramItem>) => {
    const { groups, saveGroups, settings } = get()
    set({
      groups: groups.map((g) =>
        g.id === groupId
          ? {
              ...g,
              items: settings.autoArrange
                ? sortProgramItems(g.items.map((i) => (i.id === itemId ? { ...i, ...updates } : i)))
                : g.items.map((i) => (i.id === itemId ? { ...i, ...updates } : i))
            }
          : g
      )
    })
    debouncedSaveGroups(saveGroups)
  },

  deleteItem: (groupId: string, itemId: string) => {
    const { groups, saveGroups } = get()
    set({
      groups: groups.map((g) =>
        g.id === groupId ? { ...g, items: g.items.filter((i) => i.id !== itemId) } : g
      )
    })
    debouncedSaveGroups(saveGroups)
  },

  moveItem: (fromGroupId: string, toGroupId: string, itemId: string) => {
    const { groups, saveGroups, settings } = get()
    const fromGroup = groups.find((g) => g.id === fromGroupId)
    const item = fromGroup?.items.find((i) => i.id === itemId)

    if (!item) return

    set({
      groups: groups.map((g) => {
        if (g.id === fromGroupId) {
          return { ...g, items: g.items.filter((i) => i.id !== itemId) }
        }
        if (g.id === toGroupId) {
          const movedItems = [...g.items, item]
          return {
            ...g,
            items: settings.autoArrange ? sortProgramItems(movedItems) : movedItems
          }
        }
        return g
      })
    })
    debouncedSaveGroups(saveGroups)
  },

  // Settings actions
  updateSettings: (updates: Partial<AppSettings>) => {
    const { settings, groups, saveGroups, saveSettings } = get()
    const nextSettings = { ...settings, ...updates }
    const shouldArrangeNow = !settings.autoArrange && nextSettings.autoArrange

    if (shouldArrangeNow) {
      set({
        settings: nextSettings,
        groups: groups.map((group) => ({
          ...group,
          items: sortProgramItems(group.items)
        }))
      })
      debouncedSaveGroups(saveGroups)
    } else {
      set({ settings: nextSettings })
    }

    debouncedSaveSettings(saveSettings)
  }
}))
