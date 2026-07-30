import {
  forwardRef,
  useLayoutEffect,
  useRef,
  type ButtonHTMLAttributes,
  type InputHTMLAttributes,
  type JSX,
  type ReactNode,
  type SelectHTMLAttributes
} from 'react'
import { Win95BitmapText } from './bitmapText'

export type Win95GlyphName =
  | 'close' | 'help' | 'minimize' | 'maximize' | 'restore'
  | 'menu-right' | 'menu-check' | 'menu-radio'
  | 'scroll-up' | 'scroll-down' | 'scroll-left' | 'scroll-right'
  | 'combo-down' | 'size-grip'

const GLYPH_PIXELS: Record<Exclude<Win95GlyphName, 'size-grip'>, readonly [number, number][]> = {
  close: [
    [3, 2], [4, 2], [10, 2], [11, 2], [4, 3], [5, 3], [9, 3], [10, 3],
    [5, 4], [6, 4], [8, 4], [9, 4], [6, 5], [7, 5], [8, 5],
    [6, 6], [7, 6], [8, 6], [5, 7], [6, 7], [8, 7], [9, 7],
    [4, 8], [5, 8], [9, 8], [10, 8], [3, 9], [4, 9], [10, 9], [11, 9]
  ],
  help: [
    [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [9, 3], [9, 4], [8, 5],
    [7, 6], [6, 6], [6, 7], [6, 8], [6, 10], [7, 10]
  ],
  minimize: [[3, 9], [4, 9], [5, 9], [6, 9], [7, 9], [8, 9]],
  maximize: [
    [3, 2], [4, 2], [5, 2], [6, 2], [7, 2], [8, 2], [9, 2], [10, 2],
    [3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3],
    [3, 4], [10, 4], [3, 5], [10, 5], [3, 6], [10, 6], [3, 7], [10, 7],
    [3, 8], [4, 8], [5, 8], [6, 8], [7, 8], [8, 8], [9, 8], [10, 8]
  ],
  restore: [
    [5, 2], [6, 2], [7, 2], [8, 2], [9, 2], [10, 2], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3], [10, 3],
    [5, 4], [10, 4], [2, 5], [3, 5], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [5, 6], [8, 6],
    [2, 6], [3, 6], [4, 6], [2, 7], [8, 7], [2, 8], [8, 8], [2, 9], [3, 9], [4, 9], [5, 9], [6, 9], [7, 9], [8, 9]
  ],
  'menu-right': [[3, 2], [3, 3], [4, 3], [3, 4], [4, 4], [5, 4], [3, 5], [4, 5], [5, 5], [6, 5], [3, 6], [4, 6], [5, 6], [3, 7], [4, 7], [3, 8]],
  'menu-check': [[2, 5], [3, 5], [3, 6], [4, 6], [4, 7], [5, 7], [5, 6], [6, 6], [6, 5], [7, 5], [7, 4], [8, 4], [8, 3], [9, 3]],
  'menu-radio': [[5, 4], [6, 4], [4, 5], [5, 5], [6, 5], [7, 5], [4, 6], [5, 6], [6, 6], [7, 6], [5, 7], [6, 7]],
  'scroll-up': [[6, 3], [5, 4], [6, 4], [7, 4], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [3, 6], [4, 6], [5, 6], [6, 6], [7, 6], [8, 6], [9, 6]],
  'scroll-down': [[3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [8, 4], [9, 4], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [5, 6], [6, 6], [7, 6], [6, 7]],
  'scroll-left': [[3, 6], [4, 5], [4, 6], [4, 7], [5, 4], [5, 5], [5, 6], [5, 7], [5, 8], [6, 3], [6, 4], [6, 5], [6, 6], [6, 7], [6, 8], [6, 9]],
  'scroll-right': [[8, 6], [7, 5], [7, 6], [7, 7], [6, 4], [6, 5], [6, 6], [6, 7], [6, 8], [5, 3], [5, 4], [5, 5], [5, 6], [5, 7], [5, 8], [5, 9]],
  'combo-down': [[3, 4], [4, 4], [5, 4], [6, 4], [7, 4], [8, 4], [9, 4], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [5, 6], [6, 6], [7, 6], [6, 7]]
}

export function Win95Glyph({ name, color = '#000000', className = '' }: { name: Win95GlyphName; color?: string; className?: string }): JSX.Element {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const size = name === 'size-grip' ? { width: 13, height: 13 } : { width: 14, height: 12 }
  useLayoutEffect(() => {
    const canvas = canvasRef.current
    const context = canvas?.getContext('2d')
    if (!canvas || !context) return
    canvas.width = size.width
    canvas.height = size.height
    context.clearRect(0, 0, size.width, size.height)
    if (name === 'size-grip') {
      for (const start of [4, 8, 12]) {
        for (let point = 0; point < start; point += 4) {
          const x = 12 - point
          const y = start - point
          context.fillStyle = '#ffffff'; context.fillRect(x - 1, y - 1, 2, 2)
          context.fillStyle = '#808080'; context.fillRect(x, y, 2, 2)
        }
      }
      return
    }
    context.fillStyle = color
    for (const [x, y] of GLYPH_PIXELS[name]) context.fillRect(x, y, 1, 1)
  }, [color, name, size.height, size.width])
  return <canvas ref={canvasRef} className={`win95-pixel-glyph ${className}`} width={size.width} height={size.height} aria-hidden="true" />
}

export type Win95Edge = 'raised' | 'sunken' | 'window' | 'status' | 'group'

export function Win95Frame({ edge, className = '', children }: { edge: Win95Edge; className?: string; children: ReactNode }): JSX.Element {
  return <div className={`win95-edge win95-edge-${edge} ${className}`}>{children}</div>
}

interface Win95ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  label?: string
  defaultButton?: boolean
  set?: boolean
  showAccessKey?: boolean
  children?: ReactNode
}

export const Win95Button = forwardRef<HTMLButtonElement, Win95ButtonProps>(function Win95Button({
  label,
  defaultButton = false,
  set = false,
  showAccessKey = true,
  className = '',
  children,
  disabled,
  ...props
}, ref) {
  return (
    <button
      {...props}
      ref={ref}
      disabled={disabled}
      className={`win95-control-button ${defaultButton ? 'default' : ''} ${set ? 'set' : ''} ${className}`}
      aria-label={props['aria-label'] ?? label?.replace(/&(.)/, '$1')}
    >
      {children ?? (label ? <Win95BitmapText text={label} disabled={disabled} showAccessKey={showAccessKey} /> : null)}
    </button>
  )
})

interface Win95ChoiceProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'type'> {
  label: string
}

export function Win95Checkbox({ label, className = '', disabled, ...props }: Win95ChoiceProps): JSX.Element {
  return (
    <label className={`win95-control-choice ${className}`}>
      <input {...props} type="checkbox" disabled={disabled} aria-label={label.replace(/&(.)/, '$1')} />
      <span className="win95-checkbox-box" aria-hidden="true"><Win95Glyph name="menu-check" /></span>
      <Win95BitmapText text={label} disabled={disabled} />
    </label>
  )
}

export function Win95Radio({ label, className = '', disabled, ...props }: Win95ChoiceProps): JSX.Element {
  return (
    <label className={`win95-control-choice ${className}`}>
      <input {...props} type="radio" disabled={disabled} aria-label={label.replace(/&(.)/, '$1')} />
      <span className="win95-radio-ring" aria-hidden="true"><span /></span>
      <Win95BitmapText text={label} disabled={disabled} />
    </label>
  )
}

interface Win95TextInputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string
}

export const Win95TextInput = forwardRef<HTMLInputElement, Win95TextInputProps>(function Win95TextInput({ className = '', label, ...props }, ref) {
  return <input {...props} ref={ref} className={`win95-control-text ${className}`} aria-label={props['aria-label'] ?? label?.replace(/&(.)/, '$1')} />
})

interface Win95SelectProps extends SelectHTMLAttributes<HTMLSelectElement> {
  label?: string
}

export const Win95Select = forwardRef<HTMLSelectElement, Win95SelectProps>(function Win95Select({ className = '', label, children, ...props }, ref) {
  return <span className={`win95-control-select-wrap ${className}`}><select {...props} ref={ref} aria-label={props['aria-label'] ?? label?.replace(/&(.)/, '$1')}>{children}</select><span className="win95-control-select-arrow"><Win95Glyph name="combo-down" /></span></span>
})

export function Win95GroupBox({ label, children, className = '' }: { label: string; children: ReactNode; className?: string }): JSX.Element {
  return <fieldset className={`win95-group-box ${className}`}><legend><Win95BitmapText text={label} /></legend>{children}</fieldset>
}
