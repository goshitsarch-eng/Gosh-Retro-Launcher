import { v4 as uuidv4 } from 'uuid'
import type { ProgramGroup, ProgramItem, AppSettings, WindowState } from '@shared/types'
import { DEFAULT_SETTINGS, DEFAULT_WINDOW_STATE } from '@shared/types'

// Reactive state using Svelte 5 runes
let groups = $state<ProgramGroup[]>([])
let settings = $state<AppSettings>(DEFAULT_SETTINGS)
let isLoading = $state(true)

async function saveGroups() {
  await window.electronAPI.store.set('groups', groups)
}

async function saveSettings() {
  await window.electronAPI.store.set('settings', settings)
}

export const programStore = {
  get groups() { return groups },
  get settings() { return settings },
  get isLoading() { return isLoading },

  async loadData() {
    try {
      const data = await window.electronAPI.store.getAll()
      groups = data.groups || []
      settings = { ...DEFAULT_SETTINGS, ...data.settings }
      isLoading = false
    } catch (error) {
      console.error('Failed to load data:', error)
      isLoading = false
    }
  },

  saveGroups,
  saveSettings,

  // Group actions
  addGroup(name: string): string {
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

    groups = [...groups, newGroup]
    saveGroups()
    return newGroup.id
  },

  updateGroup(id: string, updates: Partial<ProgramGroup>) {
    groups = groups.map((g) => (g.id === id ? { ...g, ...updates } : g))
    saveGroups()
  },

  deleteGroup(id: string) {
    groups = groups.filter((g) => g.id !== id)
    saveGroups()
  },

  updateGroupWindowState(id: string, windowState: Partial<WindowState>) {
    groups = groups.map((g) =>
      g.id === id ? { ...g, windowState: { ...g.windowState, ...windowState } } : g
    )
    if (settings.saveSettingsOnExit) {
      saveGroups()
    }
  },

  // Item actions
  addItem(groupId: string, item: Omit<ProgramItem, 'id'>) {
    const newItem: ProgramItem = {
      ...item,
      id: uuidv4()
    }

    groups = groups.map((g) =>
      g.id === groupId ? { ...g, items: [...g.items, newItem] } : g
    )
    saveGroups()
  },

  updateItem(groupId: string, itemId: string, updates: Partial<ProgramItem>) {
    groups = groups.map((g) =>
      g.id === groupId
        ? {
            ...g,
            items: g.items.map((i) => (i.id === itemId ? { ...i, ...updates } : i))
          }
        : g
    )
    saveGroups()
  },

  deleteItem(groupId: string, itemId: string) {
    groups = groups.map((g) =>
      g.id === groupId ? { ...g, items: g.items.filter((i) => i.id !== itemId) } : g
    )
    saveGroups()
  },

  moveItem(fromGroupId: string, toGroupId: string, itemId: string) {
    const fromGroup = groups.find((g) => g.id === fromGroupId)
    const item = fromGroup?.items.find((i) => i.id === itemId)

    if (!item) return

    groups = groups.map((g) => {
      if (g.id === fromGroupId) {
        return { ...g, items: g.items.filter((i) => i.id !== itemId) }
      }
      if (g.id === toGroupId) {
        return { ...g, items: [...g.items, item] }
      }
      return g
    })
    saveGroups()
  },

  // Settings actions
  updateSettings(updates: Partial<AppSettings>) {
    settings = { ...settings, ...updates }
    saveSettings()
  }
}
