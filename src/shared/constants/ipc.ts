// IPC Channel Constants
// All IPC communication between main and renderer uses these channel names

export const IPC_CHANNELS = {
  // Window Management
  WINDOW_MINIMIZE: 'window:minimize',
  WINDOW_MAXIMIZE: 'window:maximize',
  WINDOW_CLOSE: 'window:close',
  WINDOW_QUIT: 'window:quit',
  WINDOW_IS_MAXIMIZED: 'window:is-maximized',
  WINDOW_RECREATE_FOR_SHELL: 'window:recreate-for-shell',
  WINDOW_GET_BOUNDS: 'window:get-bounds',
  WINDOW_SET_BOUNDS: 'window:set-bounds',
  WINDOW_GET_DISPLAY_WORK_AREA: 'window:get-display-work-area',
  WINDOW_STATE_CHANGED: 'window:state-changed',
  WINDOW_DISPLAY_CHANGED: 'window:display-changed',

  // File Operations
  FILE_SELECT_EXECUTABLE: 'file:select-executable',
  FILE_SELECT_ICON: 'file:select-icon',
  FILE_EXISTS: 'file:exists',
  FILE_IMPORT_GRP: 'file:import-grp',
  FILE_EXPORT_GRP: 'file:export-grp',

  // Program Management
  PROGRAM_LAUNCH: 'program:launch',
  PROGRAM_LAUNCH_BATCH: 'program:launch-batch',

  // Store/Persistence
  STORE_GET: 'store:get',
  STORE_SET: 'store:set',
  STORE_GET_ALL: 'store:get-all',
  STORE_IMPORT: 'store:import',
  STORE_EXPORT: 'store:export',
  STORE_CHANGED: 'store:changed',
  BACKUP_LIST: 'backup:list',
  BACKUP_CREATE: 'backup:create',
  BACKUP_RESTORE: 'backup:restore',

  // System
  SYSTEM_GET_PLATFORM: 'system:get-platform',
  SYSTEM_GET_VERSION: 'system:get-version',
  SYSTEM_OPEN_EXTERNAL: 'system:open-external',

  // Quick Search
  QUICK_SEARCH_TOGGLE: 'quick-search:toggle',

  // Application Info / shell-neutral utility surface
  APP_GET_INFO: 'app:get-info',
  APP_OPEN_LAUNCHER_TOOLS: 'app:open-launcher-tools'
} as const

export type IpcChannel = (typeof IPC_CHANNELS)[keyof typeof IPC_CHANNELS]
