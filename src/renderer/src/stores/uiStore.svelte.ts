import type { ProgramItem, ProgramGroup } from '@shared/types'

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
  | null

export interface ConfirmDialogOptions {
  title: string
  message: string
  onConfirm: () => void
  onCancel?: () => void
}

export interface DialogData {
  groupId?: string
  group?: ProgramGroup
  item?: ProgramItem
  confirmOptions?: ConfirmDialogOptions
  openItemAfterCreate?: boolean
  openUrlAfterCreate?: boolean
  showIconPicker?: boolean
}

// Reactive state using Svelte 5 runes
let activeMenu = $state<string | null>(null)
let activeDialog = $state<DialogType>(null)
let dialogData = $state<DialogData>({})
let quickSearchOpen = $state(false)
let selectedItemId = $state<string | null>(null)
let selectedGroupId = $state<string | null>(null)

export const uiStore = {
  get activeMenu() { return activeMenu },
  get activeDialog() { return activeDialog },
  get dialogData() { return dialogData },
  get quickSearchOpen() { return quickSearchOpen },
  get selectedItemId() { return selectedItemId },
  get selectedGroupId() { return selectedGroupId },

  setActiveMenu(menu: string | null) {
    activeMenu = menu
  },

  openDialog(type: DialogType, data: DialogData = {}) {
    activeDialog = type
    dialogData = data
  },

  closeDialog() {
    activeDialog = null
    dialogData = {}
  },

  toggleQuickSearch() {
    quickSearchOpen = !quickSearchOpen
  },

  openQuickSearch() {
    quickSearchOpen = true
  },

  closeQuickSearch() {
    quickSearchOpen = false
  },

  setSelectedItem(itemId: string | null, groupId: string | null) {
    selectedItemId = itemId
    selectedGroupId = groupId
  },

  clearSelection() {
    selectedItemId = null
    selectedGroupId = null
  }
}
