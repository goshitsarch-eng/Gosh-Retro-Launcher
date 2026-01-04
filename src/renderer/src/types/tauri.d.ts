import type { TauriAPI } from '../lib/tauri-api'

declare global {
  interface Window {
    // Keep electronAPI name for backward compatibility during migration
    electronAPI: TauriAPI
  }
}

export {}
