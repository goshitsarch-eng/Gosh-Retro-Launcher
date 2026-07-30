import { create } from 'zustand'
import type { ProgramItem, ProgramGroup } from '@shared/types'

let launchFeedbackHideTimer: ReturnType<typeof setTimeout> | null = null

export type DialogType =
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
  | 'newObject'
  | 'moveItem'
  | 'copyItem'
  | 'run'
  | 'changeIcon'
  | 'help'
  | 'exitWindows'
  | 'unavailable'
  | null

export type Win31Selection =
  | { kind: 'item'; groupId: string; itemId: string }
  | { kind: 'groupIcon'; groupId: string }
  | null

interface ConfirmDialogOptions {
  title: string
  message: string
  onConfirm: () => void
  onCancel?: () => void
}

interface LaunchFeedbackState {
  visible: boolean
  totalGroups: number
  totalItems: number
  currentGroup: number | null
  completedGroups: number
  failures: number
  status: 'idle' | 'launching' | 'complete' | 'error'
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
    copyMode?: boolean
    helpTopic?: 'contents' | 'search' | 'using'
    title?: string
    message?: string
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
  win31Selection: Win31Selection
  setWin31Selection: (selection: Win31Selection) => void

  // Batch launch feedback
  launchFeedback: LaunchFeedbackState
  beginLaunchFeedback: (totalGroups: number, totalItems: number) => void
  updateLaunchFeedback: (currentGroup: number, completedGroups: number) => void
  finishLaunchFeedback: (failures: number) => void
  hideLaunchFeedback: () => void
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
  clearSelection: () => set({ selectedItemId: null, selectedGroupId: null, win31Selection: null }),
  win31Selection: null,
  setWin31Selection: (selection) => set({ win31Selection: selection }),

  // Batch launch feedback
  launchFeedback: {
    visible: false,
    totalGroups: 0,
    totalItems: 0,
    currentGroup: null,
    completedGroups: 0,
    failures: 0,
    status: 'idle'
  },
  beginLaunchFeedback: (totalGroups, totalItems) => {
    if (launchFeedbackHideTimer) {
      clearTimeout(launchFeedbackHideTimer)
      launchFeedbackHideTimer = null
    }
    set({
      launchFeedback: {
        visible: true,
        totalGroups,
        totalItems,
        currentGroup: null,
        completedGroups: 0,
        failures: 0,
        status: 'launching'
      }
    })
  },
  updateLaunchFeedback: (currentGroup, completedGroups) =>
    set((state) => ({
      launchFeedback: {
        ...state.launchFeedback,
        visible: true,
        currentGroup,
        completedGroups,
        status: 'launching'
      }
    })),
  finishLaunchFeedback: (failures) => {
    set((state) => ({
      launchFeedback: {
        ...state.launchFeedback,
        visible: true,
        currentGroup: null,
        completedGroups: state.launchFeedback.totalGroups,
        failures,
        status: failures > 0 ? 'error' : 'complete'
      }
    }))
    launchFeedbackHideTimer = setTimeout(() => {
      launchFeedbackHideTimer = null
      set((state) => ({
        launchFeedback: {
          ...state.launchFeedback,
          visible: false,
          status: 'idle'
        }
      }))
    }, 1800)
  },
  hideLaunchFeedback: () =>
    set((state) => ({
      launchFeedback: {
        ...state.launchFeedback,
        visible: false,
        status: 'idle'
      }
    }))
}))
