import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { inflateSync } from 'node:zlib'
import { describe, expect, it } from 'vitest'
import { WIN95_ICON_IDS } from '../iconCatalog'

interface DecodedPng { width: number; height: number; data: Buffer }
function decodeGeneratedPng(path: string): DecodedPng {
  const file = readFileSync(path)
  const width = file.readUInt32BE(16)
  const height = file.readUInt32BE(20)
  let offset = 8
  const idat: Buffer[] = []
  while (offset < file.length) {
    const length = file.readUInt32BE(offset)
    const type = file.toString('ascii', offset + 4, offset + 8)
    if (type === 'IDAT') idat.push(file.subarray(offset + 8, offset + 8 + length))
    offset += 12 + length
  }
  const raw = inflateSync(Buffer.concat(idat))
  const data = Buffer.alloc(width * height * 4)
  for (let y = 0; y < height; y += 1) {
    expect(raw[y * (width * 4 + 1)]).toBe(0)
    raw.copy(data, y * width * 4, y * (width * 4 + 1) + 1, y * (width * 4 + 1) + 1 + width * 4)
  }
  return { width, height, data }
}

const root = join(process.cwd(), 'src/renderer/src/assets/win95')

describe('clean-room Win95 icon assets', () => {
  it('ships both native families for every catalog id', () => {
    for (const id of WIN95_ICON_IDS) {
      expect(decodeGeneratedPng(join(root, 'small', `${id}-16.png`))).toMatchObject({ width: 16, height: 16 })
      expect(decodeGeneratedPng(join(root, 'large', `${id}-32.png`))).toMatchObject({ width: 32, height: 32 })
    }
  })

  it('generates every higher variant by strict nearest neighbor', () => {
    for (const [family, base] of [['small', 16], ['large', 32]] as const) {
      for (const id of WIN95_ICON_IDS) {
        const source = decodeGeneratedPng(join(root, family, `${id}-${base}.png`))
        for (const factor of [2, 3, 4]) {
          const output = decodeGeneratedPng(join(root, family, `${id}-${base * factor}.png`))
          expect(output.width).toBe(base * factor)
          const expected = Buffer.alloc(output.data.length)
          for (let y = 0; y < output.height; y += 1) for (let x = 0; x < output.width; x += 1) {
            const sourceOffset = (Math.floor(y / factor) * base + Math.floor(x / factor)) * 4
            source.data.copy(expected, (y * output.width + x) * 4, sourceOffset, sourceOffset + 4)
          }
          expect(output.data.equals(expected)).toBe(true)
        }
      }
    }
  }, 20_000)

  it('uses independently drawn small sources rather than reductions', () => {
    for (const id of ['my-computer', 'folder', 'find', 'shutdown'] as const) {
      const small = decodeGeneratedPng(join(root, 'small', `${id}-16.png`))
      const large = decodeGeneratedPng(join(root, 'large', `${id}-32.png`))
      let differs = false
      for (let y = 0; y < 16 && !differs; y += 1) for (let x = 0; x < 16; x += 1) {
        const smallOffset = (y * 16 + x) * 4
        const largeOffset = ((y * 2) * 32 + x * 2) * 4
        if (!small.data.subarray(smallOffset, smallOffset + 4).equals(large.data.subarray(largeOffset, largeOffset + 4))) { differs = true; break }
      }
      expect(differs).toBe(true)
    }
  })
})
