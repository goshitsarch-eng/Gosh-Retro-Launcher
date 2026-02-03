import Store from 'electron-store'
import type { StoreData, AppSettings, ProgramGroup } from '@shared/types'
import { DEFAULT_SETTINGS } from '@shared/types'

interface StoreSchema {
  groups: ProgramGroup[]
  settings: AppSettings
}

let store: Store<StoreSchema> | null = null

export function initStore(): Store<StoreSchema> {
  store = new Store<StoreSchema>({
    name: 'program-manager-data',
    defaults: {
      groups: [],
      settings: DEFAULT_SETTINGS
    }
  })

  return store
}

export function getStore(): Store<StoreSchema> {
  if (!store) {
    throw new Error('Store not initialized. Call initStore() first.')
  }
  return store
}

export function getGroups(): ProgramGroup[] {
  return getStore().get('groups', [])
}

export function setGroups(groups: ProgramGroup[]): void {
  getStore().set('groups', groups)
}

export function getSettings(): AppSettings {
  return getStore().get('settings', DEFAULT_SETTINGS)
}

export function setSettings(settings: AppSettings): void {
  getStore().set('settings', settings)
}

export function getAllData(): StoreData {
  const storeInstance = getStore()
  return {
    groups: storeInstance.get('groups', []),
    settings: storeInstance.get('settings', DEFAULT_SETTINGS)
  }
}

export function setAllData(data: StoreData): void {
  const storeInstance = getStore()
  storeInstance.set('groups', data.groups)
  storeInstance.set('settings', data.settings)
}

export function clearStore(): void {
  getStore().clear()
}
