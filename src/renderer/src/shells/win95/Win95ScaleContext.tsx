import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type JSX,
  type ReactNode
} from 'react'
import { useProgramStore } from '@/store/programStore'
import {
  logicalViewportSize,
  resolveWin95AutoScale,
  toWin95LogicalDelta,
  toWin95LogicalPoint,
  type Win95ScaleFactor
} from './tokens'
import { setWin95RuntimeScale } from './iconCatalog'

interface ViewportSize {
  width: number
  height: number
}

interface Win95ScaleValue {
  scale: Win95ScaleFactor
  viewport: ViewportSize
  logicalViewport: ViewportSize
  toLogicalDelta: (physicalDelta: number) => number
  toLogicalPoint: (
    clientX: number,
    clientY: number,
    origin?: { left: number; top: number }
  ) => { x: number; y: number }
}

const initialViewport = {
  width: typeof window === 'undefined' ? 640 : window.innerWidth,
  height: typeof window === 'undefined' ? 480 : window.innerHeight
}

const Win95ScaleContext = createContext<Win95ScaleValue>({
  scale: 1,
  viewport: initialViewport,
  logicalViewport: initialViewport,
  toLogicalDelta: (value) => value,
  toLogicalPoint: (x, y, origin = { left: 0, top: 0 }) => ({
    x: x - origin.left,
    y: y - origin.top
  })
})

export function Win95ScaleProvider({ children }: { children: ReactNode }): JSX.Element {
  const preference = useProgramStore((state) => state.settings.win95Scale)
  const [viewport, setViewport] = useState<ViewportSize>(initialViewport)

  useEffect(() => {
    let frame = 0
    const measure = (): void => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
        setViewport({
          width: Math.max(1, window.innerWidth),
          height: Math.max(1, window.innerHeight)
        })
      })
    }
    measure()
    window.addEventListener('resize', measure)
    return () => {
      cancelAnimationFrame(frame)
      window.removeEventListener('resize', measure)
    }
  }, [])

  const scale = useMemo<Win95ScaleFactor>(() => {
    if (preference !== 'auto') return preference
    return resolveWin95AutoScale(viewport.width, viewport.height)
  }, [preference, viewport.height, viewport.width])

  useEffect(() => setWin95RuntimeScale(scale), [scale])

  const logicalViewport = useMemo(
    () => logicalViewportSize(viewport.width, viewport.height, scale),
    [scale, viewport.height, viewport.width]
  )
  const toLogicalDelta = useCallback((value: number) => toWin95LogicalDelta(value, scale), [scale])
  const toLogicalPoint = useCallback((
    clientX: number,
    clientY: number,
    origin = { left: 0, top: 0 }
  ) => toWin95LogicalPoint(clientX, clientY, scale, origin), [scale])

  const value = useMemo(() => ({
    scale,
    viewport,
    logicalViewport,
    toLogicalDelta,
    toLogicalPoint
  }), [logicalViewport, scale, toLogicalDelta, toLogicalPoint, viewport])

  return <Win95ScaleContext.Provider value={value}>{children}</Win95ScaleContext.Provider>
}

export function useWin95Scale(): Win95ScaleValue {
  return useContext(Win95ScaleContext)
}
