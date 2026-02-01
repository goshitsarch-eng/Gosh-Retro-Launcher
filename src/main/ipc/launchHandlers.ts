import { ipcMain, shell } from 'electron'
import { spawn } from 'child_process'
import { readFileSync } from 'fs'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import type { ProgramItem } from '@shared/types'

// Parse Linux .desktop file
function parseDesktopFile(filePath: string): { exec: string; name: string } | null {
  try {
    const content = readFileSync(filePath, 'utf-8')
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

// Launch a program based on platform
async function launchProgram(item: ProgramItem): Promise<{ success: boolean; error?: string }> {
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
          spawn(details.target, details.args?.split(' ') ?? [], {
            cwd: details.cwd || workingDir || undefined,
            detached: true,
            stdio: 'ignore'
          }).unref()
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
          spawn('open', ['-a', programPath], {
            detached: true,
            stdio: 'ignore'
          }).unref()
        } else {
          spawn(programPath, [], {
            cwd: workingDir || undefined,
            detached: true,
            stdio: 'ignore'
          }).unref()
        }
        break
      }

      case 'linux': {
        // Linux: Parse .desktop files, spawn executables
        if (programPath.endsWith('.desktop')) {
          const desktop = parseDesktopFile(programPath)
          if (desktop) {
            const parts = desktop.exec.split(/\s+/)
            spawn(parts[0], parts.slice(1), {
              cwd: workingDir || undefined,
              detached: true,
              stdio: 'ignore'
            }).unref()
          } else {
            return { success: false, error: 'Could not parse .desktop file' }
          }
        } else {
          spawn(programPath, [], {
            cwd: workingDir || undefined,
            detached: true,
            stdio: 'ignore'
          }).unref()
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
      await shell.openExternal(url)
      return { success: true }
    } catch (error) {
      return { success: false, error: String(error) }
    }
  })
}
