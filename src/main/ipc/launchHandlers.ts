import { ipcMain, shell } from 'electron'
import { spawn } from 'child_process'
import { readFile } from 'fs/promises'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import type { ProgramItem } from '@shared/types'

// Tokenize a shell-like command string, respecting quotes
function tokenizeCommand(cmd: string): string[] {
  const tokens: string[] = []
  let current = ''
  let inSingle = false
  let inDouble = false
  let escape = false

  for (const ch of cmd) {
    if (escape) {
      current += ch
      escape = false
      continue
    }

    if (ch === '\\' && !inSingle) {
      escape = true
      continue
    }

    if (ch === "'" && !inDouble) {
      inSingle = !inSingle
      continue
    }

    if (ch === '"' && !inSingle) {
      inDouble = !inDouble
      continue
    }

    if (/\s/.test(ch) && !inSingle && !inDouble) {
      if (current) {
        tokens.push(current)
        current = ''
      }
      continue
    }

    current += ch
  }

  if (current) tokens.push(current)
  return tokens
}

// Validate that an exec path looks safe (no shell metacharacters in command name)
function isValidExecPath(execPath: string): boolean {
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
  options: { cwd?: string }
): void {
  const child = spawn(command, args, {
    cwd: options.cwd,
    detached: true,
    stdio: 'ignore'
  })
  child.on('error', (err) => {
    console.error(`Failed to spawn ${command}:`, err.message)
  })
  child.unref()
}

// Launch a program based on platform
export async function launchProgram(item: ProgramItem): Promise<{ success: boolean; error?: string }> {
  const { path: programPath, workingDir } = item

  // Handle URLs
  if (programPath.startsWith('http://') || programPath.startsWith('https://')) {
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
          const args = details.args ? tokenizeCommand(details.args) : []
          spawnDetached(details.target, args, {
            cwd: details.cwd || workingDir || undefined
          })
        } else {
          const error = await shell.openPath(programPath)
          if (error) {
            return { success: false, error }
          }
        }
        break
      }

      case 'darwin': {
        // macOS: Use 'open' for .app bundles, spawn for executables
        if (programPath.endsWith('.app')) {
          spawnDetached('open', ['-a', programPath], {})
        } else {
          spawnDetached(programPath, [], {
            cwd: workingDir || undefined
          })
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
            spawnDetached(parts[0], parts.slice(1), {
              cwd: workingDir || undefined
            })
          } else {
            return { success: false, error: 'Could not parse .desktop file' }
          }
        } else {
          spawnDetached(programPath, [], {
            cwd: workingDir || undefined
          })
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
  ipcMain.handle(IPC_CHANNELS.PROGRAM_LAUNCH, async (_, item: ProgramItem) => {
    return launchProgram(item)
  })

  ipcMain.handle(
    IPC_CHANNELS.PROGRAM_LAUNCH_BATCH,
    async (_, items: ProgramItem[], delay: number) => {
      const results: Array<{ id: string; success: boolean; error?: string }> = []

      for (let i = 0; i < items.length; i++) {
        const item = items[i]
        const result = await launchProgram(item)
        results.push({ id: item.id, ...result })

        // Wait between launches (except for the last one)
        if (i < items.length - 1 && delay > 0) {
          await new Promise((resolve) => setTimeout(resolve, delay))
        }
      }

      return results
    }
  )

  ipcMain.handle(IPC_CHANNELS.SYSTEM_OPEN_EXTERNAL, async (_, url: string) => {
    try {
      const parsed = new URL(url)
      if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
        return { success: false, error: 'Only http and https URLs are allowed' }
      }
      await shell.openExternal(url)
      return { success: true }
    } catch (error) {
      return { success: false, error: String(error) }
    }
  })
}
