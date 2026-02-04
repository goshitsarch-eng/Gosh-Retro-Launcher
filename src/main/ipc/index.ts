import { registerWindowHandlers } from './windowHandlers'
import { registerFileHandlers } from './fileHandlers'
import { registerStoreHandlers } from './storeHandlers'
import { registerLaunchHandlers } from './launchHandlers'
import { registerAppInfoHandlers } from './appInfoHandlers'

export function registerIpcHandlers(): void {
  registerWindowHandlers()
  registerFileHandlers()
  registerStoreHandlers()
  registerLaunchHandlers()
  registerAppInfoHandlers()
}
