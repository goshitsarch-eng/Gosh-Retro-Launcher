import { useMemo, type CSSProperties, type JSX, type ReactNode } from 'react'
import { WIN95_METRICS } from './tokens'

export interface Win95AccessText {
  text: string
  accessIndex: number
  accessKey: string | null
}

const NARROW = new Set(" !'.,:;Iijl|`\")[]{}")
const WIDE = new Set('MW@%&mw')
const MEDIUM = new Set('ABCDEFGHKNOPQRSTUVXYZ023456789')

/**
 * Deterministic logical advances for the project-owned 11px MS Sans Serif
 * recreation. Painting uses the same advances and turns every glyph into a
 * one-bit mask, so browser subpixel colour never reaches shell captures.
 */
export function win95GlyphAdvance(character: string, bold = false, fontPx: number = WIN95_METRICS.systemFontPx): number {
  let base: number
  if (character === '\t') base = 16
  else if (character === ' ') base = 4
  else if (NARROW.has(character)) base = character === 'I' || character === 'l' ? 3 : 4
  else if (WIDE.has(character)) base = bold ? 9 : 8
  else if (MEDIUM.has(character)) base = bold ? 8 : 7
  else base = bold ? 7 : 6
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
  const parsed = useMemo(() => parseWin95AccessText(source), [source])
  const lines = useMemo(() => {
    if (wrap && maxWidth) return wrapWin95Text(parsed.text, maxWidth, bold, fontPx)
    return [maxWidth ? clipWin95Text(parsed.text, maxWidth, bold, fontPx) : parsed.text]
  }, [bold, fontPx, maxWidth, parsed.text, wrap])
  const naturalWidth = Math.max(1, ...lines.map((line) => measureWin95Text(line, bold, fontPx)))
  const width = Math.max(1, Math.min(maxWidth ?? naturalWidth, naturalWidth))
  const height = Math.max(lineHeight, lines.length * lineHeight)
  const ink = (
    <span
      className={`win95-bitmap-text-ink ${disabled ? 'disabled' : ''} ${desktopShadow ? 'desktop-shadow' : ''}`}
      aria-hidden="true"
      style={{ width, height, color: disabled ? '#808080' : color, fontSize: fontPx, fontWeight: bold ? 700 : 400, lineHeight: `${lineHeight}px` }}
    >
      {lines.map((line, index) => (
        <span className="win95-bitmap-text-line" key={`${line}-${index}`}>
          {renderAccessLine(line, parsed.text, parsed.accessIndex, showAccessKey)}
        </span>
      ))}
    </span>
  )
  return (
    <span
      className={`win95-bitmap-text ${vertical ? 'vertical' : ''} ${className}`}
      style={{ ...(vertical ? { width: height, height: width } : { width, height }), ...style }}
      role={role}
      aria-label={parsed.text}
      data-access-key={parsed.accessKey ?? undefined}
    >
      {vertical ? <span className="win95-bitmap-text-rotator" style={{ width, height }}>{ink}</span> : ink}
      <span className="win95-semantic-text">{parsed.text}</span>
    </span>
  )
}
