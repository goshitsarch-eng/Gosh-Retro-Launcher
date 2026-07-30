import { create } from 'zustand'
import { v4 as uuidv4 } from 'uuid'
import type {
  ProgramGroup,
  ProgramItem,
  AppSettings,
  WindowState,
  LogicalPosition,
  ShellType,
  WorkspaceProfile
} from '@shared/types'
import {
  DEFAULT_SETTINGS,
  DEFAULT_WINDOW_STATE,
  createShellWindowState,
  getGroupWindowState
} from '@shared/types'
import { migrateStoreData } from '@shared/storeMigration'

let saveGroupsTimer: ReturnType<typeof setTimeout> | null = null
let saveSettingsTimer: ReturnType<typeof setTimeout> | null = null

function debouncedSaveGroups(saveGroups: () => Promise<void>): void {
  if (saveGroupsTimer) clearTimeout(saveGroupsTimer)
  saveGroupsTimer = setTimeout(() => {
    saveGroupsTimer = null
    void saveGroups()
  }, 300)
}

function debouncedSaveSettings(saveSettings: () => Promise<void>): void {
  if (saveSettingsTimer) clearTimeout(saveSettingsTimer)
  saveSettingsTimer = setTimeout(() => {
    saveSettingsTimer = null
    void saveSettings()
  }, 300)
}

interface ProgramState {
  groups: ProgramGroup[]
  settings: AppSettings
  workspaceProfiles: WorkspaceProfile[]
  isLoading: boolean

  loadData: () => Promise<void>
  saveGroups: () => Promise<void>
  saveSettings: () => Promise<void>
  saveWorkspaceProfiles: () => Promise<void>

  addGroup: (name: string) => string
  importGroup: (group: ProgramGroup) => void
  replaceGroups: (groups: ProgramGroup[]) => void
  addStarterWorkspace: () => void
  updateGroup: (id: string, updates: Partial<ProgramGroup>) => void
  deleteGroup: (id: string) => void
  updateGroupWindowState: (
    id: string,
    windowState: Partial<WindowState>,
    shellOverride?: ShellType
  ) => void
  updateGroupIconPosition: (id: string, position: LogicalPosition) => void

  addItem: (groupId: string, item: Omit<ProgramItem, 'id'>) => void
  updateItem: (groupId: string, itemId: string, updates: Partial<ProgramItem>) => void
  updateItemPosition: (groupId: string, itemId: string, position: LogicalPosition) => void
  updateWin95ItemPosition: (groupId: string, itemId: string, position: LogicalPosition) => void
  deleteItem: (groupId: string, itemId: string) => void
  moveItem: (fromGroupId: string, toGroupId: string, itemId: string) => void
  copyItem: (fromGroupId: string, toGroupId: string, itemId: string) => void

  saveWorkspaceProfile: (name: string) => string
  applyWorkspaceProfile: (id: string) => void
  deleteWorkspaceProfile: (id: string) => void
  renameWorkspaceProfile: (id: string, name: string) => void

  updateSettings: (updates: Partial<AppSettings>) => void
}

function makeGroup(name: string, index: number): ProgramGroup {
  const baseState: WindowState = {
    ...DEFAULT_WINDOW_STATE,
    x: DEFAULT_WINDOW_STATE.x + index * 30,
    y: DEFAULT_WINDOW_STATE.y + index * 30
  }
  return {
    id: uuidv4(),
    name,
    icon: 'folder',
    windowState: { ...baseState },
    shellWindowState: createShellWindowState(baseState),
    win31IconPosition: { x: (index % 8) * 75, y: 368 - Math.floor(index / 8) * 58 },
    items: []
  }
}

export const useProgramStore = create<ProgramState>((set, get) => ({
  groups: [],
  settings: DEFAULT_SETTINGS,
  workspaceProfiles: [],
  isLoading: true,

  loadData: async () => {
    try {
      const loaded = migrateStoreData(await window.electronAPI.store.getAll())
      set({
        groups: loaded.groups,
        settings: loaded.settings,
        workspaceProfiles: loaded.workspaceProfiles,
        isLoading: false
      })
    } catch (error) {
      console.error('Failed to load data:', error)
      set({ isLoading: false })
    }
  },

  saveGroups: async () => {
    await window.electronAPI.store.set('groups', get().groups)
  },

  saveSettings: async () => {
    await window.electronAPI.store.set('settings', get().settings)
  },

  saveWorkspaceProfiles: async () => {
    await window.electronAPI.store.set('workspaceProfiles', get().workspaceProfiles)
  },

  addGroup: (name: string) => {
    const { groups, saveGroups } = get()
    const group = makeGroup(name, groups.length)
    set({ groups: [...groups, group] })
    debouncedSaveGroups(saveGroups)
    return group.id
  },

  importGroup: (group) => {
    const { groups, saveGroups } = get()
    const existingIds = new Set(groups.map((entry) => entry.id))
    const imported = structuredClone(group)
    if (existingIds.has(imported.id)) imported.id = uuidv4()
    imported.items = imported.items.map((item) => ({
      ...item,
      id: groups.some((entry) => entry.items.some((existing) => existing.id === item.id)) ? uuidv4() : item.id
    }))
    set({ groups: [...groups, imported] })
    debouncedSaveGroups(saveGroups)
  },

  replaceGroups: (groups) => {
    const { saveGroups } = get()
    set({ groups: structuredClone(groups) })
    debouncedSaveGroups(saveGroups)
  },

  addStarterWorkspace: () => {
    const { groups, saveGroups } = get()
    const names = ['Main', 'Accessories', 'Games', 'Utilities', 'Internet']
    const existingNames = new Set(groups.map((group) => group.name.toLowerCase()))
    const newGroups = names
      .filter((name) => !existingNames.has(name.toLowerCase()))
      .map((name, index) => {
        const group = makeGroup(name, groups.length + index)
        const minimized = name !== 'Main'
        group.shellWindowState.win31.minimized = minimized
        group.shellWindowState.win95.minimized = minimized
        group.windowState.minimized = minimized
        return group
      })
    if (newGroups.length === 0) return
    set({ groups: [...groups, ...newGroups] })
    debouncedSaveGroups(saveGroups)
  },

  updateGroup: (id, updates) => {
    const { groups, saveGroups } = get()
    set({ groups: groups.map((group) => group.id === id ? { ...group, ...updates } : group) })
    debouncedSaveGroups(saveGroups)
  },

  deleteGroup: (id) => {
    const { groups, saveGroups } = get()
    set({ groups: groups.filter((group) => group.id !== id) })
    debouncedSaveGroups(saveGroups)
  },

  updateGroupWindowState: (id, updates, shellOverride) => {
    const { groups, saveGroups, settings } = get()
    const shell = shellOverride ?? settings.shell
    set({
      groups: groups.map((group) => {
        if (group.id !== id) return group
        const current = getGroupWindowState(group, shell)
        const shellWindowState = {
          ...group.shellWindowState,
          [shell]: { ...current, ...updates }
        }
        return {
          ...group,
          shellWindowState,
          // Stable legacy mirror for old exports; no renderer reads this field.
          windowState: { ...shellWindowState.win31 }
        }
      })
    })
    if (settings.saveSettingsOnExit) debouncedSaveGroups(saveGroups)
  },

  updateGroupIconPosition: (id, position) => {
    const { groups, saveGroups, settings } = get()
    set({ groups: groups.map((group) => group.id === id ? { ...group, win31IconPosition: position } : group) })
    if (settings.saveSettingsOnExit) debouncedSaveGroups(saveGroups)
  },

  addItem: (groupId, item) => {
    const { groups, saveGroups } = get()
    const newItem: ProgramItem = { ...item, id: uuidv4() }
    set({ groups: groups.map((group) => group.id === groupId
      ? { ...group, items: [...group.items, newItem] }
      : group) })
    debouncedSaveGroups(saveGroups)
  },

  updateItem: (groupId, itemId, updates) => {
    const { groups, saveGroups } = get()
    set({ groups: groups.map((group) => group.id === groupId
      ? { ...group, items: group.items.map((item) => item.id === itemId ? { ...item, ...updates } : item) }
      : group) })
    debouncedSaveGroups(saveGroups)
  },

  updateItemPosition: (groupId, itemId, position) => {
    get().updateItem(groupId, itemId, { win31Position: position })
  },

  updateWin95ItemPosition: (groupId, itemId, position) => {
    get().updateItem(groupId, itemId, { win95Position: position })
  },

  deleteItem: (groupId, itemId) => {
    const { groups, saveGroups } = get()
    set({ groups: groups.map((group) => group.id === groupId
      ? { ...group, items: group.items.filter((item) => item.id !== itemId) }
      : group) })
    debouncedSaveGroups(saveGroups)
  },

  moveItem: (fromGroupId, toGroupId, itemId) => {
    if (fromGroupId === toGroupId) return
    const { groups, saveGroups } = get()
    const item = groups.find((group) => group.id === fromGroupId)?.items.find((entry) => entry.id === itemId)
    if (!item) return
    set({ groups: groups.map((group) => {
      if (group.id === fromGroupId) return { ...group, items: group.items.filter((entry) => entry.id !== itemId) }
      if (group.id === toGroupId) return { ...group, items: [...group.items, { ...item, win31Position: undefined, win95Position: undefined }] }
      return group
    }) })
    debouncedSaveGroups(saveGroups)
  },

  copyItem: (fromGroupId, toGroupId, itemId) => {
    const { groups, saveGroups } = get()
    const item = groups.find((group) => group.id === fromGroupId)?.items.find((entry) => entry.id === itemId)
    if (!item) return
    const copy: ProgramItem = { ...item, id: uuidv4(), win31Position: undefined, win95Position: undefined }
    set({ groups: groups.map((group) => group.id === toGroupId
      ? { ...group, items: [...group.items, copy] }
      : group) })
    debouncedSaveGroups(saveGroups)
  },

  saveWorkspaceProfile: (name) => {
    const { groups, workspaceProfiles, saveWorkspaceProfiles } = get()
    const now = new Date().toISOString()
    const profile: WorkspaceProfile = {
      id: uuidv4(),
      name: name.trim() || `Workspace ${workspaceProfiles.length + 1}`,
      groups: structuredClone(groups),
      createdAt: now,
      updatedAt: now
    }
    set({ workspaceProfiles: [...workspaceProfiles, profile] })
    void saveWorkspaceProfiles()
    return profile.id
  },

  applyWorkspaceProfile: (id) => {
    const profile = get().workspaceProfiles.find((entry) => entry.id === id)
    if (!profile) return
    get().replaceGroups(profile.groups)
  },

  deleteWorkspaceProfile: (id) => {
    const { workspaceProfiles, saveWorkspaceProfiles } = get()
    set({ workspaceProfiles: workspaceProfiles.filter((entry) => entry.id !== id) })
    void saveWorkspaceProfiles()
  },

  renameWorkspaceProfile: (id, name) => {
    const { workspaceProfiles, saveWorkspaceProfiles } = get()
    const trimmed = name.trim()
    if (!trimmed) return
    set({ workspaceProfiles: workspaceProfiles.map((entry) => entry.id === id
      ? { ...entry, name: trimmed, updatedAt: new Date().toISOString() }
      : entry) })
    void saveWorkspaceProfiles()
  },

  updateSettings: (updates) => {
    const { settings, saveSettings } = get()
    set({ settings: { ...settings, ...updates } })
    debouncedSaveSettings(saveSettings)
  }
}))
