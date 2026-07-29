import { ipcMain, shell } from 'electron'
import { spawn } from 'child_process'
import { readFile } from 'fs/promises'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import type { ProgramItem } from '@shared/types'

const MAX_BATCH_ITEMS = 200
const MAX_LAUNCH_DELAY_MS = 10_000

function isValidLaunchUrl(url: string): boolean {
  try {
    const parsed = new URL(url)
    return parsed.protocol === 'http:' || parsed.protocol === 'https:'
  } catch {
    return false
  }
}

function isProgramItem(value: unknown): value is ProgramItem {
  if (typeof value !== 'object' || value === null) return false
  const obj = value as Record<string, unknown>
  return (
    typeof obj.id === 'string' &&
    typeof obj.name === 'string' &&
    typeof obj.path === 'string' &&
    typeof obj.icon === 'string' &&
    typeof obj.workingDir === 'string' &&
    (obj.arguments === undefined || typeof obj.arguments === 'string') &&
    (obj.environment === undefined || typeof obj.environment === 'string') &&
    (obj.runMode === undefined || ['normal', 'minimized', 'maximized'].includes(obj.runMode as string)) &&
    (obj.runMinimized === undefined || typeof obj.runMinimized === 'boolean') &&
    (obj.launchGroup === undefined ||
      (typeof obj.launchGroup === 'number' &&
        Number.isInteger(obj.launchGroup) &&
        obj.launchGroup >= 0))
  )
}

// Tokenize a shell-like command string, respecting quotes
export function tokenizeCommand(cmd: string): string[] {
  const tokens: string[] = []
  let current = ''
  let inSingle = false
  let inDouble = false

  for (let index = 0; index < cmd.length; index += 1) {
    const ch = cmd[index]
    const next = cmd[index + 1]
    if (ch === '\\' && !inSingle) {
      // Preserve ordinary Windows path separators; only escape characters that
      // are meaningful to this tokenizer.
      if (next && (/\s/.test(next) || next === '"' || next === "'" || next === '\\')) {
        current += next
        index += 1
      } else {
        current += ch
      }
      continue
    }
    if (ch === "'" && !inDouble) { inSingle = !inSingle; continue }
    if (ch === '"' && !inSingle) { inDouble = !inDouble; continue }
    if (/\s/.test(ch) && !inSingle && !inDouble) {
      if (current) { tokens.push(current); current = '' }
      continue
    }
    current += ch
  }

  if (current) tokens.push(current)
  return tokens
}

// Validate that an exec path looks safe (no shell metacharacters in command name)
export function isValidExecPath(execPath: string): boolean {
  // Reject if empty or contains shell operators
  if (!execPath) return false
  // Only validate the command itself (first token) - reject shell metacharacters
  if (/[;&|`$(){}]/.test(execPath)) return false
  return true
}

// Parse Linux .desktop file
async function parseDesktopFile(filePath: string): Promise<{ exec: string; name: string } | null> {
  try {
    // Verify the file path ends with .desktop
    if (!filePath.endsWith('.desktop')) return null

    const content = await readFile(filePath, 'utf-8')
    const lines = content.split('\n')

    let exec = ''
    let name = ''
    let inDesktopEntry = false

    for (const line of lines) {
      const trimmed = line.trim()

      if (trimmed === '[Desktop Entry]') {
        inDesktopEntry = true
        continue
      }

      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        inDesktopEntry = false
        continue
      }

      if (!inDesktopEntry) continue

      if (trimmed.startsWith('Exec=')) {
        exec = trimmed.substring(5)
      } else if (trimmed.startsWith('Name=')) {
        name = trimmed.substring(5)
      }
    }

    if (exec) {
      // Remove field codes like %f, %u, %F, %U
      exec = exec.replace(/%[fFuUdDnNickvm]/g, '').trim()
      return { exec, name }
    }

    return null
  } catch {
    return null
  }
}

// Spawn a process with error handling
function spawnDetached(
  command: string,
  args: string[],
  options: { cwd?: string; env?: NodeJS.ProcessEnv; windowsHide?: boolean }
): void {
  const child = spawn(command, args, {
    cwd: options.cwd,
    detached: true,
    stdio: 'ignore',
    env: options.env,
    windowsHide: options.windowsHide
  })
  child.on('error', (err) => {
    console.error(`Failed to spawn ${command}:`, err.message)
  })
  child.unref()
}

export function parseEnvironment(value = ''): NodeJS.ProcessEnv {
  const additions: NodeJS.ProcessEnv = {}
  for (const line of value.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue
    const separator = trimmed.indexOf('=')
    if (separator <= 0) continue
    additions[trimmed.slice(0, separator).trim()] = trimmed.slice(separator + 1)
  }
  return { ...process.env, ...additions }
}

// Launch a program based on platform
export async function launchProgram(item: ProgramItem): Promise<{ success: boolean; error?: string }> {
  const { path: programPath, workingDir } = item
  const itemArguments = tokenizeCommand(item.arguments ?? '')
  const environment = parseEnvironment(item.environment)
  const runMode = item.runMode ?? (item.runMinimized ? 'minimized' : 'normal')
  const spawnOptions = {
    cwd: workingDir || undefined,
    env: environment,
    windowsHide: runMode === 'minimized'
  }

  // Handle URLs
  if (isValidLaunchUrl(programPath)) {
    try {
      await shell.openExternal(programPath)
      return { success: true }
    } catch (error) {
      return { success: false, error: String(error) }
    }
  }

  try {
    switch (process.platform) {
      case 'win32': {
        // Windows: Use shell.openPath for most files
        const ext = programPath.toLowerCase().split('.').pop()

        if (ext === 'lnk') {
          // Read shortcut and launch target
          const details = shell.readShortcutLink(programPath)
          const args = [...(details.args ? tokenizeCommand(details.args) : []), ...itemArguments]
          spawnDetached(details.target, args, {
            ...spawnOptions,
            cwd: details.cwd || workingDir || undefined
          })
        } else if (['exe', 'com'].includes(ext ?? '') && runMode !== 'normal') {
          const windowStyle = runMode === 'maximized' ? 'Maximized' : 'Minimized'
          const script = `$launch=@{FilePath=$args[0];WindowStyle='${windowStyle}'}; ` +
            `if($args.Count -gt 1){$launch.ArgumentList=$args[1..($args.Count-1)]}; ` +
            `if($env:GOSH_LAUNCH_CWD){$launch.WorkingDirectory=$env:GOSH_LAUNCH_CWD}; Start-Process @launch`
          spawnDetached('powershell.exe', [
            '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', script, programPath, ...itemArguments
          ], { ...spawnOptions, env: { ...environment, GOSH_LAUNCH_CWD: workingDir || '' } })
        } else if (['exe', 'com'].includes(ext ?? '') && (itemArguments.length > 0 || item.environment)) {
          spawnDetached(programPath, itemArguments, spawnOptions)
        } else if (['bat', 'cmd'].includes(ext ?? '')) {
          spawnDetached(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', programPath, ...itemArguments], spawnOptions)
        } else {
          const error = await shell.openPath(programPath)
          if (error) return { success: false, error }
        }
        break
      }

      case 'darwin': {
        // macOS: Use 'open' for .app bundles, spawn for executables
        if (programPath.endsWith('.app')) {
          spawnDetached('open', ['-a', programPath, ...(itemArguments.length ? ['--args', ...itemArguments] : [])], spawnOptions)
        } else {
          spawnDetached(programPath, itemArguments, spawnOptions)
        }
        break
      }

      case 'linux': {
        // Linux: Parse .desktop files, spawn executables
        if (programPath.endsWith('.desktop')) {
          const desktop = await parseDesktopFile(programPath)
          if (desktop) {
            const parts = tokenizeCommand(desktop.exec)
            if (parts.length === 0 || !isValidExecPath(parts[0])) {
              return { success: false, error: 'Invalid Exec command in .desktop file' }
            }
            spawnDetached(parts[0], [...parts.slice(1), ...itemArguments], spawnOptions)
          } else {
            return { success: false, error: 'Could not parse .desktop file' }
          }
        } else {
          spawnDetached(programPath, itemArguments, spawnOptions)
        }
        break
      }
    }

    return { success: true }
  } catch (error) {
    return { success: false, error: String(error) }
  }
}

export function registerLaunchHandlers(): void {
  ipcMain.handle(IPC_CHANNELS.PROGRAM_LAUNCH, async (_, item: unknown) => {
    if (!isProgramItem(item)) {
      return { success: false, error: 'Invalid program item payload' }
    }
    return launchProgram(item)
  })

  ipcMain.handle(
    IPC_CHANNELS.PROGRAM_LAUNCH_BATCH,
    async (_, items: unknown, delay: unknown) => {
      if (!Array.isArray(items) || !items.every(isProgramItem)) {
        return [{ id: 'unknown', success: false, error: 'Invalid program batch payload' }]
      }
      if (items.length > MAX_BATCH_ITEMS) {
        return [
          {
            id: 'unknown',
            success: false,
            error: `Batch size exceeds ${MAX_BATCH_ITEMS} items`
          }
        ]
      }

      const clampedDelay =
        typeof delay === 'number' && Number.isFinite(delay)
          ? Math.max(0, Math.min(Math.floor(delay), MAX_LAUNCH_DELAY_MS))
          : 0

      const results: Array<{ id: string; success: boolean; error?: string }> = []

      for (let i = 0; i < items.length; i++) {
        const item = items[i]
        const result = await launchProgram(item)
        results.push({ id: item.id, ...result })

        // Wait between launches (except for the last one)
        if (i < items.length - 1 && clampedDelay > 0) {
          await new Promise((resolve) => setTimeout(resolve, clampedDelay))
        }
      }

      return results
    }
  )

  ipcMain.handle(IPC_CHANNELS.SYSTEM_OPEN_EXTERNAL, async (_, url: string) => {
    try {
      if (!isValidLaunchUrl(url)) {
        return { success: false, error: 'Only http and https URLs are allowed' }
      }
      await shell.openExternal(url)
      return { success: true }
    } catch (error) {
      return { success: false, error: String(error) }
    }
  })
}
