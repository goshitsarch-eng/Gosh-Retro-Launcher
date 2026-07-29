import { app } from 'electron'
import Store from 'electron-store'
import { join } from 'path'
import type { StoreData, AppSettings, ProgramGroup, WorkspaceProfile } from '@shared/types'
import { CURRENT_SCHEMA_VERSION, DEFAULT_SETTINGS } from '@shared/types'
import { migrateStoreData } from '@shared/storeMigration'
import { createBackup, recoverCorruptStoreFile } from './backups'

interface StoreSchema {
  schemaVersion: number
  groups: ProgramGroup[]
  settings: AppSettings
  workspaceProfiles: WorkspaceProfile[]
}

let store: Store<StoreSchema> | null = null

export function initStore(): Store<StoreSchema> {
  recoverCorruptStoreFile(join(app.getPath('userData'), 'program-manager-data.json'))
  store = new Store<StoreSchema>({
    name: 'program-manager-data',
    defaults: {
      schemaVersion: CURRENT_SCHEMA_VERSION,
      groups: [],
      settings: DEFAULT_SETTINGS,
      workspaceProfiles: []
    }
  })

  // electron-store applies defaults per key, so normalize the complete payload
  // once to migrate legacy single-shell geometry and newly added preferences.
  const migrated = migrateStoreData({
    schemaVersion: store.get('schemaVersion'),
    groups: store.get('groups', []),
    settings: store.get('settings', DEFAULT_SETTINGS),
    workspaceProfiles: store.get('workspaceProfiles', [])
  })
  store.set(migrated)

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
  void createBackup(getAllData(), 'groups-changed')
  getStore().set('groups', groups)
}

export function getSettings(): AppSettings {
  return { ...DEFAULT_SETTINGS, ...getStore().get('settings', DEFAULT_SETTINGS) }
}

export function setSettings(settings: AppSettings): void {
  void createBackup(getAllData(), 'settings-changed')
  getStore().set('settings', { ...DEFAULT_SETTINGS, ...settings })
}

export function getWorkspaceProfiles(): WorkspaceProfile[] {
  return getStore().get('workspaceProfiles', [])
}

export function setWorkspaceProfiles(profiles: WorkspaceProfile[]): void {
  void createBackup(getAllData(), 'profiles-changed')
  getStore().set('workspaceProfiles', profiles)
}

export function getAllData(): StoreData {
  return migrateStoreData({
    schemaVersion: getStore().get('schemaVersion', CURRENT_SCHEMA_VERSION),
    groups: getGroups(),
    settings: getSettings(),
    workspaceProfiles: getWorkspaceProfiles()
  })
}

export function setAllData(data: StoreData): void {
  const normalized = migrateStoreData(data)
  void createBackup(getAllData(), 'store-replaced', true)
  getStore().set(normalized)
}

export function clearStore(): void {
  void createBackup(getAllData(), 'store-cleared', true)
  getStore().clear()
}
