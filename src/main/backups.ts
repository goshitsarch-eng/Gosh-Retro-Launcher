import { app } from 'electron'
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, statSync } from 'fs'
import { readFile, writeFile, unlink } from 'fs/promises'
import { basename, join } from 'path'
import { migrateStoreData } from '@shared/storeMigration'
import type { BackupInfo, StoreData } from '@shared/types'

const BACKUP_LIMIT = 12
let lastAutomaticBackup = 0

function backupDirectory(): string {
  return join(app.getPath('userData'), 'backups')
}

function safeReason(reason: string): string {
  return reason.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 32) || 'backup'
}

function parseBackupName(name: string): { createdAt: string; reason: string } | null {
  const match = /^(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}[.-]\d{3}Z)--(.+)\.json$/.exec(name)
  if (!match) return null
  return { createdAt: match[1].replace(/T(\d{2})-(\d{2})-(\d{2})[.-](\d{3})Z$/, 'T$1:$2:$3.$4Z'), reason: match[2] }
}

export function listBackups(): BackupInfo[] {
  const directory = backupDirectory()
  if (!existsSync(directory)) return []
  return readdirSync(directory)
    .map((id): BackupInfo | null => {
      const parsed = parseBackupName(id)
      if (!parsed) return null
      try {
        return { id, createdAt: parsed.createdAt, reason: parsed.reason, size: statSync(join(directory, id)).size }
      } catch {
        return null
      }
    })
    .filter((entry): entry is BackupInfo => entry !== null)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
}

async function pruneBackups(): Promise<void> {
  const stale = listBackups().slice(BACKUP_LIMIT)
  await Promise.all(stale.map((entry) => unlink(join(backupDirectory(), entry.id)).catch(() => undefined)))
}

export async function createBackup(
  data: StoreData,
  reason: string,
  force = false
): Promise<BackupInfo | null> {
  const now = Date.now()
  if (!force && now - lastAutomaticBackup < 30_000) return null
  if (!force) lastAutomaticBackup = now
  const directory = backupDirectory()
  mkdirSync(directory, { recursive: true })
  const createdAt = new Date(now).toISOString()
  const id = `${createdAt.replace(/:/g, '-')}--${safeReason(reason)}.json`
  const serialized = JSON.stringify(migrateStoreData(data), null, 2)
  await writeFile(join(directory, id), serialized, 'utf8')
  await pruneBackups()
  return { id, createdAt, reason: safeReason(reason), size: Buffer.byteLength(serialized) }
}

export async function readBackup(id: string): Promise<StoreData> {
  if (basename(id) !== id || !id.endsWith('.json')) throw new Error('Invalid backup identifier')
  const content = await readFile(join(backupDirectory(), id), 'utf8')
  return migrateStoreData(JSON.parse(content))
}

/** Recover malformed electron-store JSON before electron-store opens it. */
export function recoverCorruptStoreFile(storeFile: string): boolean {
  if (!existsSync(storeFile)) return false
  try {
    JSON.parse(readFileSync(storeFile, 'utf8'))
    return false
  } catch {
    const corruptName = `${storeFile}.corrupt-${Date.now()}`
    renameSync(storeFile, corruptName)
    const latest = listBackups()[0]
    if (!latest) return false
    copyFileSync(join(backupDirectory(), latest.id), storeFile)
    return true
  }
}
