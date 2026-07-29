import {
  DEFAULT_WINDOW_STATE,
  createShellWindowState,
  type ProgramGroup,
  type ProgramItem,
  type WindowState
} from './types'

const PMCC = [0x50, 0x4d, 0x43, 0x43] as const
const HEADER_SIZE = 32
const ITEM_SIZE = 20
const MAX_ITEMS = 512

export class GrpFormatError extends Error {}

function readCString(bytes: Uint8Array, offset: number): string {
  if (!Number.isInteger(offset) || offset <= 0 || offset >= bytes.length) return ''
  let end = offset
  while (end < bytes.length && bytes[end] !== 0) end += 1
  return new TextDecoder('windows-1252').decode(bytes.subarray(offset, end)).trim()
}

function encodeAnsi(value: string): Uint8Array {
  const bytes = new Uint8Array(value.length + 1)
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index)
    bytes[index] = code <= 0xff ? code : 0x3f
  }
  return bytes
}

function makeId(prefix: string, index: number, idFactory?: () => string): string {
  if (idFactory) return idFactory()
  const random = Math.random().toString(36).slice(2, 10)
  return `${prefix}-${Date.now().toString(36)}-${index}-${random}`
}

export function splitLegacyCommand(command: string): { path: string; arguments: string } {
  const value = command.trim()
  if (!value) return { path: '', arguments: '' }
  if (value.startsWith('"')) {
    const closing = value.indexOf('"', 1)
    if (closing > 0) return {
      path: value.slice(1, closing),
      arguments: value.slice(closing + 1).trim()
    }
  }
  const executable = /^(.+?\.(?:exe|com|bat|cmd|pif))(?:\s+(.*))?$/i.exec(value)
  if (executable) return { path: executable[1], arguments: executable[2] ?? '' }
  const separator = value.search(/\s/)
  return separator < 0
    ? { path: value, arguments: '' }
    : { path: value.slice(0, separator), arguments: value.slice(separator + 1).trim() }
}

export function parseWin31Grp(
  input: Uint8Array,
  idFactory?: () => string
): ProgramGroup {
  if (input.length < HEADER_SIZE) throw new GrpFormatError('The file is too small to be a Program Manager group.')
  if (!PMCC.every((byte, index) => input[index] === byte)) {
    throw new GrpFormatError('The file does not contain a PMCC Program Manager group header.')
  }
  const view = new DataView(input.buffer, input.byteOffset, input.byteLength)
  const declaredSize = view.getUint16(6, true)
  const fileSize = declaredSize >= HEADER_SIZE && declaredSize <= input.length ? declaredSize : input.length
  const bytes = input.subarray(0, fileSize)
  const count = view.getUint16(30, true)
  if (count > MAX_ITEMS || HEADER_SIZE + count * 2 > fileSize) {
    throw new GrpFormatError('The Program Manager group has an invalid item table.')
  }

  const groupName = readCString(bytes, view.getUint16(22, true)) || 'Imported Group'
  const left = view.getInt16(10, true)
  const top = view.getInt16(12, true)
  const right = view.getInt16(14, true)
  const bottom = view.getInt16(16, true)
  const width = Math.max(150, right > left ? right - left : DEFAULT_WINDOW_STATE.width)
  const height = Math.max(92, bottom > top ? bottom - top : DEFAULT_WINDOW_STATE.height)
  const showCommand = view.getUint16(8, true)
  const groupState: WindowState = {
    x: Math.max(0, left),
    y: Math.max(0, top),
    width,
    height,
    minimized: showCommand === 2 || showCommand === 6,
    maximized: showCommand === 3
  }

  const items: ProgramItem[] = []
  for (let index = 0; index < count; index += 1) {
    const itemOffset = view.getUint16(HEADER_SIZE + index * 2, true)
    if (itemOffset < HEADER_SIZE || itemOffset + ITEM_SIZE > fileSize) continue
    const name = readCString(bytes, view.getUint16(itemOffset + 14, true)) || `Program ${index + 1}`
    const command = readCString(bytes, view.getUint16(itemOffset + 16, true))
    const iconPath = readCString(bytes, view.getUint16(itemOffset + 18, true))
    const parsed = splitLegacyCommand(command)
    if (!parsed.path) continue
    items.push({
      id: makeId('grp-item', index, idFactory),
      name,
      path: parsed.path,
      arguments: parsed.arguments,
      workingDir: '',
      icon: 'default',
      ...(iconPath && iconPath !== parsed.path ? { win31Icon: 'default' } : {}),
      win31Position: {
        x: Math.max(0, view.getInt16(itemOffset, true)),
        y: Math.max(0, view.getInt16(itemOffset + 2, true))
      }
    })
  }

  return {
    id: makeId('grp', 0, idFactory),
    name: groupName,
    icon: 'group',
    windowState: { ...groupState },
    shellWindowState: createShellWindowState(groupState),
    items
  }
}

interface MutableChunk {
  bytes: number[]
  offsets: Map<string, number>
}

function appendString(chunk: MutableChunk, key: string, value: string): number {
  if (chunk.bytes.length % 2) chunk.bytes.push(0)
  const offset = chunk.bytes.length
  chunk.offsets.set(key, offset)
  chunk.bytes.push(...encodeAnsi(value))
  return offset
}

function commandFor(item: ProgramItem): string {
  const quoted = /\s/.test(item.path) ? `"${item.path}"` : item.path
  return item.arguments?.trim() ? `${quoted} ${item.arguments.trim()}` : quoted
}

/** Serialize the documented PMCC subset used by Windows 3.x Program Manager. */
export function serializeWin31Grp(group: ProgramGroup): Uint8Array {
  if (group.items.length > MAX_ITEMS) throw new GrpFormatError(`A .GRP file can contain at most ${MAX_ITEMS} items.`)
  const tableSize = HEADER_SIZE + group.items.length * 2
  const itemBase = tableSize + (tableSize % 2)
  const itemOffsets = group.items.map((_, index) => itemBase + index * ITEM_SIZE)
  const chunk: MutableChunk = {
    bytes: new Array(itemBase + group.items.length * ITEM_SIZE).fill(0),
    offsets: new Map()
  }

  const groupNameOffset = appendString(chunk, 'group', group.name)
  const strings = group.items.map((item, index) => ({
    name: appendString(chunk, `name-${index}`, item.name),
    command: appendString(chunk, `command-${index}`, commandFor(item)),
    icon: appendString(chunk, `icon-${index}`, item.path)
  }))
  if (chunk.bytes.length % 2) chunk.bytes.push(0)
  if (chunk.bytes.length > 0xffff) throw new GrpFormatError('The group is too large for the Windows 3.x .GRP format.')

  const output = new Uint8Array(chunk.bytes)
  const view = new DataView(output.buffer)
  PMCC.forEach((byte, index) => { output[index] = byte })
  view.setUint16(6, output.length, true)
  const state = group.shellWindowState?.win31 ?? group.windowState
  view.setUint16(8, state.minimized ? 2 : state.maximized ? 3 : 1, true)
  view.setInt16(10, Math.max(-32768, Math.min(32767, Math.round(state.x))), true)
  view.setInt16(12, Math.max(-32768, Math.min(32767, Math.round(state.y))), true)
  view.setInt16(14, Math.max(-32768, Math.min(32767, Math.round(state.x + state.width))), true)
  view.setInt16(16, Math.max(-32768, Math.min(32767, Math.round(state.y + state.height))), true)
  view.setInt16(18, 0, true)
  view.setInt16(20, 0, true)
  view.setUint16(22, groupNameOffset, true)
  view.setUint16(24, 32, true)
  view.setUint16(26, 32, true)
  view.setUint16(28, 1, true)
  view.setUint16(30, group.items.length, true)

  group.items.forEach((item, index) => {
    const offset = itemOffsets[index]
    view.setUint16(HEADER_SIZE + index * 2, offset, true)
    view.setInt16(offset, Math.max(0, Math.min(32767, Math.round(item.win31Position?.x ?? (index % 5) * 75))), true)
    view.setInt16(offset + 2, Math.max(0, Math.min(32767, Math.round(item.win31Position?.y ?? Math.floor(index / 5) * 72))), true)
    view.setUint16(offset + 4, 0, true)
    view.setUint16(offset + 6, 0, true)
    view.setUint16(offset + 8, 0, true)
    view.setUint16(offset + 10, 0, true)
    view.setUint16(offset + 12, 0, true)
    view.setUint16(offset + 14, strings[index].name, true)
    view.setUint16(offset + 16, strings[index].command, true)
    view.setUint16(offset + 18, strings[index].icon, true)
  })

  // Program Manager validates that the unsigned 16-bit word sum is zero.
  let sum = 0
  for (let offset = 0; offset < output.length; offset += 2) {
    sum = (sum + (output[offset] | ((output[offset + 1] ?? 0) << 8))) & 0xffff
  }
  view.setUint16(4, (-sum) & 0xffff, true)
  return output
}
