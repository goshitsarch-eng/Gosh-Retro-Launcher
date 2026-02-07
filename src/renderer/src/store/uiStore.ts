import { create } from 'zustand'
import type { ProgramItem, ProgramGroup } from '@shared/types'

type DialogType =
  | 'newGroup'
  | 'renameGroup'
  | 'groupProperties'
  | 'newItem'
  | 'newUrl'
  | 'itemProperties'
  | 'settings'
  | 'about'
  | 'confirm'
  | 'welcome'
  | null

interface ConfirmDialogOptions {
  title: string
  message: string
  onConfirm: () => void
  onCancel?: () => void
}

interface UIState {
  // Menu state
  activeMenu: string | null
  setActiveMenu: (menu: string | null) => void

  // Dialog state
  activeDialog: DialogType
  dialogData: {
    groupId?: string
    group?: ProgramGroup
    item?: ProgramItem
    confirmOptions?: ConfirmDialogOptions
    openItemAfterCreate?: boolean
    openUrlAfterCreate?: boolean
    showIconPicker?: boolean
  }
  openDialog: (type: DialogType, data?: UIState['dialogData']) => void
  closeDialog: () => void

  // Quick search state
  quickSearchOpen: boolean
  toggleQuickSearch: () => void
  openQuickSearch: () => void
  closeQuickSearch: () => void

  // Selection state
  selectedItemId: string | null
  selectedGroupId: string | null
  setSelectedItem: (itemId: string | null, groupId: string | null) => void
  clearSelection: () => void
}

export const useUIStore = create<UIState>((set) => ({
  // Menu state
  activeMenu: null,
  setActiveMenu: (menu) => set({ activeMenu: menu }),

  // Dialog state
  activeDialog: null,
  dialogData: {},
  openDialog: (type, data = {}) =>
    set({ activeDialog: type, dialogData: data }),
  closeDialog: () => set({ activeDialog: null, dialogData: {} }),

  // Quick search state
  quickSearchOpen: false,
  toggleQuickSearch: () =>
    set((state) => ({ quickSearchOpen: !state.quickSearchOpen })),
  openQuickSearch: () => set({ quickSearchOpen: true }),
  closeQuickSearch: () => set({ quickSearchOpen: false }),

  // Selection state
  selectedItemId: null,
  selectedGroupId: null,
  setSelectedItem: (itemId, groupId) =>
    set({ selectedItemId: itemId, selectedGroupId: groupId }),
  clearSelection: () => set({ selectedItemId: null, selectedGroupId: null })
}))
