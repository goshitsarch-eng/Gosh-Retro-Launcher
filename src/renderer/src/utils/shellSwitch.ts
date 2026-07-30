import type { AppSettings } from '@shared/types'

export interface ShellSwitchDependencies {
  persist: (settings: AppSettings) => Promise<unknown>
  updateRenderer: (settings: AppSettings) => void
  recreate: (shell: AppSettings['shell']) => Promise<unknown>
}

export interface ShellSwitchResult {
  success: boolean
  error?: string
}

/** Persist-first transaction required because main validates settings before recreation. */
export async function applyShellSettingsTransaction(
  previous: AppSettings,
  next: AppSettings,
  dependencies: ShellSwitchDependencies
): Promise<ShellSwitchResult> {
  try {
    await dependencies.persist(next)
    dependencies.updateRenderer(next)
    if (next.shell !== previous.shell) await dependencies.recreate(next.shell)
    return { success: true }
  } catch (error) {
    try { await dependencies.persist(previous) } catch { /* renderer rollback still prevents split-brain UI */ }
    dependencies.updateRenderer(previous)
    return { success: false, error: error instanceof Error ? error.message : String(error) }
  }
}
