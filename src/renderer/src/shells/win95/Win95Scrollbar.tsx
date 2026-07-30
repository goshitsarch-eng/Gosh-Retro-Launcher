import { useMemo, useRef, type JSX, type PointerEvent as ReactPointerEvent } from 'react'
import { Win95Glyph } from './Win95Primitives'
import {
  win95ScrollFromThumb,
  win95ScrollPage,
  win95ScrollStep,
  win95ThumbMetrics,
  win95ThumbOffset
} from './scrollbarState'

interface Win95ScrollbarProps {
  orientation: 'vertical' | 'horizontal'
  value: number
  viewportSize: number
  contentSize: number
  length: number
  onChange: (value: number) => void
  lineSize?: number
}

export function Win95Scrollbar({
  orientation,
  value,
  viewportSize,
  contentSize,
  length,
  onChange,
  lineSize = 16
}: Win95ScrollbarProps): JSX.Element {
  const vertical = orientation === 'vertical'
  const arrow = 16
  const trackLength = Math.max(0, length - arrow * 2)
  const baseMetrics = useMemo(() => win95ThumbMetrics(viewportSize, contentSize, trackLength), [contentSize, trackLength, viewportSize])
  const metrics = { ...baseMetrics, thumbOffset: win95ThumbOffset(value, baseMetrics) }
  const repeatRef = useRef<{ delay?: number; interval?: number } | null>(null)
  const valueRef = useRef(value)
  valueRef.current = value
  const dragRef = useRef<{ pointerId: number; start: number; thumb: number } | null>(null)

  const stopRepeat = (): void => {
    if (repeatRef.current?.delay) window.clearTimeout(repeatRef.current.delay)
    if (repeatRef.current?.interval) window.clearInterval(repeatRef.current.interval)
    repeatRef.current = null
  }
  const startRepeat = (action: () => void): void => {
    stopRepeat(); action()
    const state: { delay?: number; interval?: number } = {}
    state.delay = window.setTimeout(() => { state.interval = window.setInterval(action, 55) }, 350)
    repeatRef.current = state
  }
  const step = (direction: -1 | 1): void => {
    const next = win95ScrollStep(valueRef.current, direction, lineSize, contentSize, viewportSize)
    valueRef.current = next; onChange(next)
  }
  const page = (direction: -1 | 1): void => {
    const next = win95ScrollPage(valueRef.current, direction, contentSize, viewportSize)
    valueRef.current = next; onChange(next)
  }
  const point = (event: ReactPointerEvent): number => vertical ? event.clientY : event.clientX

  return (
    <div
      className={`win95-scrollbar ${orientation}`}
      style={vertical ? { height: length } : { width: length }}
      role="scrollbar"
      aria-orientation={orientation}
      aria-valuemin={0}
      aria-valuemax={metrics.maxScroll}
      aria-valuenow={value}
      tabIndex={-1}
      onPointerMove={(event) => {
        const drag = dragRef.current
        if (!drag || drag.pointerId !== event.pointerId) return
        const offset = drag.thumb + point(event) - drag.start
        onChange(win95ScrollFromThumb(offset, metrics))
      }}
      onPointerUp={(event) => {
        stopRepeat()
        if (dragRef.current?.pointerId === event.pointerId) dragRef.current = null
        if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId)
      }}
      onPointerCancel={(event) => {
        stopRepeat(); dragRef.current = null
        if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId)
      }}
    >
      <button type="button" className="win95-scroll-arrow first" disabled={value <= 0} aria-label={`Scroll ${vertical ? 'up' : 'left'}`}
        onPointerDown={(event) => { if (event.button === 0 && value > 0) { event.currentTarget.closest<HTMLElement>('.win95-scrollbar')?.setPointerCapture(event.pointerId); startRepeat(() => step(-1)) } }}>
        <Win95Glyph name={vertical ? 'scroll-up' : 'scroll-left'} />
      </button>
      <div className="win95-scroll-track"
        onPointerDown={(event) => {
          if (event.button !== 0 || event.target !== event.currentTarget || !metrics.maxScroll) return
          event.currentTarget.closest<HTMLElement>('.win95-scrollbar')?.setPointerCapture(event.pointerId)
          const bounds = event.currentTarget.getBoundingClientRect()
          const coordinate = (vertical ? event.clientY - bounds.top : event.clientX - bounds.left)
          startRepeat(() => page(coordinate < metrics.thumbOffset ? -1 : 1))
        }}>
        <button type="button" className="win95-scroll-thumb" disabled={!metrics.maxScroll}
          style={vertical
            ? { height: metrics.thumbLength, top: metrics.thumbOffset }
            : { width: metrics.thumbLength, left: metrics.thumbOffset }}
          aria-label="Scroll thumb"
          onPointerDown={(event) => {
            if (event.button !== 0 || !metrics.maxScroll) return
            event.stopPropagation()
            event.currentTarget.closest<HTMLElement>('.win95-scrollbar')?.setPointerCapture(event.pointerId)
            dragRef.current = { pointerId: event.pointerId, start: point(event), thumb: metrics.thumbOffset }
          }} />
      </div>
      <button type="button" className="win95-scroll-arrow last" disabled={value >= metrics.maxScroll} aria-label={`Scroll ${vertical ? 'down' : 'right'}`}
        onPointerDown={(event) => { if (event.button === 0 && value < metrics.maxScroll) { event.currentTarget.closest<HTMLElement>('.win95-scrollbar')?.setPointerCapture(event.pointerId); startRepeat(() => step(1)) } }}>
        <Win95Glyph name={vertical ? 'scroll-down' : 'scroll-right'} />
      </button>
    </div>
  )
}
