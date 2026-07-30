import { useLayoutEffect, useMemo, useRef, useState, type CSSProperties, type JSX, type ReactNode } from 'react'
import { WIN95_METRICS } from './tokens'

interface RtmFontGlyph { x: number; width: number; advance: number }
interface RtmFontAtlas { height: number; glyphs: Record<string, RtmFontGlyph> }

const rtmFontImages = import.meta.glob('../../assets/win95-rtm-local/font/*.png', {
  eager: true, query: '?url', import: 'default'
}) as Record<string, string>
const rtmFontData = import.meta.glob('../../assets/win95-rtm-local/font/*.json', {
  eager: true, import: 'default'
}) as Record<string, RtmFontAtlas>
const NORMAL_FONT_PATH = '../../assets/win95-rtm-local/font/ms-sans-serif-8'
const BOLD_FONT_PATH = '../../assets/win95-rtm-local/font/ms-sans-serif-8-bold'

// Widths from the 8-point, 96-DPI MS Sans Serif strike. Keeping metrics in
// code makes clipping deterministic even when the user's local RTM atlas is
// absent and the distributable fallback face is used.
const RTM_ASCII_WIDTHS = [3,3,5,7,6,8,6,2,3,3,4,6,3,3,3,5,6,6,6,6,6,6,6,6,6,6,3,3,6,6,6,6,11,7,7,7,8,7,6,8,8,3,5,7,6,9,8,8,7,8,8,7,7,8,7,11,7,7,7,3,5,3,6,6,3,6,6,6,6,6,3,6,6,2,2,6,2,8,6,6,6,6,3,5,3,6,6,8,5,5,5,4,2,4,7] as const

export interface Win95AccessText {
  text: string
  accessIndex: number
  accessKey: string | null
}

function fontAtlas(bold: boolean): RtmFontAtlas | undefined {
  return rtmFontData[`${bold ? BOLD_FONT_PATH : NORMAL_FONT_PATH}.json`]
}
function atlasGlyph(character: string, bold: boolean): RtmFontGlyph | undefined {
  const atlas = fontAtlas(bold)
  return atlas?.glyphs[String(character.codePointAt(0) ?? 63)] ?? atlas?.glyphs['63']
}

/** Exact RTM 8-point screen-font advances at the canonical 96-DPI grid. */
export function win95GlyphAdvance(character: string, bold = false, fontPx: number = WIN95_METRICS.systemFontPx): number {
  let base: number
  if (character === '\t') base = 12
  else {
    const code = character.codePointAt(0) ?? 63
    const actual = atlasGlyph(character, bold)?.advance
    if (actual) base = actual
    else if (code >= 32 && code <= 126) base = RTM_ASCII_WIDTHS[code - 32] + (bold && code !== 32 ? 1 : 0)
    else base = bold ? 7 : 6
  }
  return Math.max(1, Math.round(base * fontPx / WIN95_METRICS.systemFontPx))
}

export function parseWin95AccessText(source: string): Win95AccessText {
  let text = ''
  let accessIndex = -1
  let accessKey: string | null = null
  for (let index = 0; index < source.length; index += 1) {
    const character = source[index]
    if (character !== '&') {
      text += character
      continue
    }
    if (source[index + 1] === '&') {
      text += '&'
      index += 1
      continue
    }
    if (source[index + 1] && accessIndex < 0) {
      accessIndex = text.length
      accessKey = source[index + 1].toLowerCase()
      continue
    }
  }
  return { text, accessIndex, accessKey }
}

export function measureWin95Text(source: string, bold = false, fontPx: number = WIN95_METRICS.systemFontPx): number {
  const { text } = parseWin95AccessText(source)
  let width = 0
  for (const character of text) width += win95GlyphAdvance(character, bold, fontPx)
  return width
}

export function clipWin95Text(source: string, maxWidth: number, bold = false, fontPx: number = WIN95_METRICS.systemFontPx): string {
  const parsed = parseWin95AccessText(source).text
  if (measureWin95Text(parsed, bold, fontPx) <= maxWidth) return parsed
  let result = ''
  let width = 0
  for (const character of parsed) {
    const next = width + win95GlyphAdvance(character, bold, fontPx)
    if (next > maxWidth) break
    result += character
    width = next
  }
  return result
}

export function wrapWin95Text(source: string, maxWidth: number, bold = false, fontPx: number = WIN95_METRICS.systemFontPx): string[] {
  const text = parseWin95AccessText(source).text
  const explicit = text.split('\n')
  const lines: string[] = []
  for (const paragraph of explicit) {
    if (!paragraph) { lines.push(''); continue }
    const words = paragraph.split(' ')
    let line = ''
    for (const word of words) {
      const candidate = line ? `${line} ${word}` : word
      if (measureWin95Text(candidate, bold, fontPx) <= maxWidth) { line = candidate; continue }
      if (line) lines.push(line)
      if (measureWin95Text(word, bold, fontPx) <= maxWidth) { line = word; continue }
      let remainder = word
      while (remainder) {
        const chunk = clipWin95Text(remainder, maxWidth, bold, fontPx)
        if (!chunk) break
        lines.push(chunk)
        remainder = remainder.slice(chunk.length)
      }
      line = ''
    }
    if (line || !lines.length) lines.push(line)
  }
  return lines
}

function colorToRgba(color: string): [number, number, number, number] {
  const value = color.startsWith('#') ? color.slice(1) : '000000'
  const hex = value.length === 3 ? [...value].map((part) => part + part).join('') : value
  return [Number.parseInt(hex.slice(0, 2), 16) || 0, Number.parseInt(hex.slice(2, 4), 16) || 0, Number.parseInt(hex.slice(4, 6), 16) || 0, 255]
}

function paintMask(context: CanvasRenderingContext2D, mask: Uint8ClampedArray, width: number, height: number, color: string, offsetX = 0, offsetY = 0): void {
  const output = context.getImageData(0, 0, context.canvas.width, context.canvas.height)
  const rgba = colorToRgba(color)
  for (let y = 0; y < height; y += 1) for (let x = 0; x < width; x += 1) {
    if (!mask[(y * width + x) * 4 + 3]) continue
    const targetX = x + offsetX; const targetY = y + offsetY
    if (targetX < 0 || targetY < 0 || targetX >= output.width || targetY >= output.height) continue
    const target = (targetY * output.width + targetX) * 4
    output.data[target] = rgba[0]; output.data[target + 1] = rgba[1]; output.data[target + 2] = rgba[2]; output.data[target + 3] = 255
  }
  context.putImageData(output, 0, 0)
}

function renderAccessLine(line: string, fullText: string, accessIndex: number, showAccessKey: boolean): ReactNode {
  if (!showAccessKey || accessIndex < 0 || line !== fullText) return line
  return <>{line.slice(0, accessIndex)}<span className="win95-access-character">{line[accessIndex]}</span>{line.slice(accessIndex + 1)}</>
}

export interface Win95BitmapTextProps {
  text: string
  bold?: boolean
  color?: string
  disabled?: boolean
  desktopShadow?: boolean
  showAccessKey?: boolean
  maxWidth?: number
  wrap?: boolean
  vertical?: boolean
  className?: string
  style?: CSSProperties
  role?: string
  fontPx?: number
  lineHeight?: number
}

export function Win95BitmapText({
  text: source,
  bold = false,
  color = '#000000',
  disabled = false,
  desktopShadow = false,
  showAccessKey = true,
  maxWidth,
  wrap = false,
  vertical = false,
  className = '',
  style,
  role,
  fontPx = WIN95_METRICS.systemFontPx,
  lineHeight = fontPx === WIN95_METRICS.systemFontPx ? WIN95_METRICS.labelLineHeight : fontPx + 1
}: Win95BitmapTextProps): JSX.Element {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [atlasImage, setAtlasImage] = useState<HTMLImageElement | null>(null)
  const parsed = useMemo(() => parseWin95AccessText(source), [source])
  const lines = useMemo(() => {
    if (wrap && maxWidth) return wrapWin95Text(parsed.text, maxWidth, bold, fontPx)
    return [maxWidth ? clipWin95Text(parsed.text, maxWidth, bold, fontPx) : parsed.text]
  }, [bold, fontPx, maxWidth, parsed.text, wrap])
  const naturalWidth = Math.max(1, ...lines.map((line) => measureWin95Text(line, bold, fontPx)))
  const width = Math.max(1, Math.min(maxWidth ?? naturalWidth, naturalWidth))
  const height = Math.max(lineHeight, lines.length * lineHeight)
  const atlas = fontAtlas(bold)
  const atlasUrl = rtmFontImages[`${bold ? BOLD_FONT_PATH : NORMAL_FONT_PATH}.png`]
  const useActualAtlas = !!atlas && !!atlasUrl && fontPx === WIN95_METRICS.systemFontPx && !vertical

  useLayoutEffect(() => {
    if (!useActualAtlas || !atlasUrl) { setAtlasImage(null); return }
    let active = true
    const image = new Image()
    image.onload = (): void => { if (active) setAtlasImage(image) }
    image.src = atlasUrl
    if (image.complete) setAtlasImage(image)
    return () => { active = false }
  }, [atlasUrl, useActualAtlas])

  useLayoutEffect(() => {
    if (!useActualAtlas || !atlasImage || !atlas) return
    const canvas = canvasRef.current
    if (!canvas) return
    const extra = desktopShadow || disabled ? 1 : 0
    canvas.width = width + extra; canvas.height = height + extra
    const context = canvas.getContext('2d', { alpha: true })
    if (!context) return
    context.clearRect(0, 0, canvas.width, canvas.height)
    const scratch = document.createElement('canvas')
    scratch.width = canvas.width; scratch.height = canvas.height
    const sourceContext = scratch.getContext('2d', { alpha: true })
    if (!sourceContext) return
    sourceContext.imageSmoothingEnabled = false
    lines.forEach((line, lineIndex) => {
      let x = 0
      for (const character of line) {
        const glyph = atlasGlyph(character, bold)
        if (!glyph) continue
        sourceContext.drawImage(atlasImage, glyph.x, 0, glyph.width, atlas.height, x, lineIndex * lineHeight, glyph.width, atlas.height)
        x += glyph.advance
      }
    })
    const mask = sourceContext.getImageData(0, 0, scratch.width, scratch.height).data
    if (disabled) paintMask(context, mask, scratch.width, scratch.height, '#ffffff', 1, 1)
    else if (desktopShadow) paintMask(context, mask, scratch.width, scratch.height, '#000000', 1, 1)
    paintMask(context, mask, scratch.width, scratch.height, disabled ? '#808080' : color)
    if (showAccessKey && parsed.accessIndex >= 0 && lines.length === 1) {
      const x = measureWin95Text(parsed.text.slice(0, parsed.accessIndex), bold, fontPx)
      const underlineWidth = Math.max(1, win95GlyphAdvance(parsed.text[parsed.accessIndex], bold, fontPx) - 1)
      context.fillStyle = disabled ? '#808080' : color
      context.fillRect(x, lineHeight - 2, Math.min(underlineWidth, canvas.width - x), 1)
    }
  }, [atlas, atlasImage, bold, color, desktopShadow, disabled, fontPx, height, lineHeight, lines, parsed.accessIndex, parsed.text, showAccessKey, useActualAtlas, width])

  const cssInk = (
    <span className={`win95-bitmap-text-ink ${disabled ? 'disabled' : ''} ${desktopShadow ? 'desktop-shadow' : ''}`} aria-hidden="true"
      style={{ width, height, color: disabled ? '#808080' : color, fontSize: fontPx, fontWeight: bold ? 700 : 400, lineHeight: `${lineHeight}px` }}>
      {lines.map((line, index) => <span className="win95-bitmap-text-line" key={`${line}-${index}`}>{renderAccessLine(line, parsed.text, parsed.accessIndex, showAccessKey)}</span>)}
    </span>
  )
  const ink = useActualAtlas ? <canvas ref={canvasRef} className="win95-bitmap-text-canvas" aria-hidden="true" /> : cssInk
  return (
    <span className={`win95-bitmap-text ${vertical ? 'vertical' : ''} ${className}`}
      style={{ ...(vertical ? { width: height, height: width } : { width, height }), ...style }} role={role}
      aria-label={parsed.text} data-access-key={parsed.accessKey ?? undefined}>
      {vertical ? <span className="win95-bitmap-text-rotator" style={{ width, height }}>{ink}</span> : ink}
      <span className="win95-semantic-text">{parsed.text}</span>
    </span>
  )
}
