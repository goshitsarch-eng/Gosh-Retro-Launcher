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
import type { DisplayWorkArea } from '@shared/types'
import { IPC_CHANNELS } from '@shared/constants/ipc'
import { useProgramStore } from '@/store/programStore'
import { resolveWfwAutoScale, type WfwScaleFactor } from './tokens'

interface Win31ScaleValue {
  scale: WfwScaleFactor
  display: DisplayWorkArea | null
  toLogicalDelta: (physicalDelta: number) => number
  toLogicalPoint: (physicalX: number, physicalY: number) => { x: number; y: number }
}

const Win31ScaleContext = createContext<Win31ScaleValue>({
  scale: 1,
  display: null,
  toLogicalDelta: (value) => value,
  toLogicalPoint: (x, y) => ({ x, y })
})

export function Win31ScaleProvider({ children }: { children: ReactNode }): JSX.Element {
  const preference = useProgramStore((state) => state.settings.win31Scale)
  const [display, setDisplay] = useState<DisplayWorkArea | null>(null)

  useEffect(() => {
    let active = true
    void window.electronAPI.window.getDisplayWorkArea().then((nextDisplay) => {
      if (active) setDisplay(nextDisplay)
    })
    const handleDisplay = (...args: unknown[]): void => {
      const nextDisplay = args[0] as DisplayWorkArea
      if (nextDisplay && typeof nextDisplay.width === 'number') setDisplay(nextDisplay)
    }
    window.electronAPI.on(IPC_CHANNELS.WINDOW_DISPLAY_CHANGED, handleDisplay)
    return () => {
      active = false
      window.electronAPI.off(IPC_CHANNELS.WINDOW_DISPLAY_CHANGED, handleDisplay)
    }
  }, [])

  const scale = useMemo<WfwScaleFactor>(() => {
    if (preference !== 'auto') return preference
    return display ? resolveWfwAutoScale(display.width, display.height) : 1
  }, [display, preference])

  useEffect(() => {
    document.documentElement.style.setProperty('--wfw-ui-scale', String(scale))
    document.documentElement.dataset.wfwScale = String(scale)
    return () => {
      document.documentElement.style.removeProperty('--wfw-ui-scale')
      delete document.documentElement.dataset.wfwScale
    }
  }, [scale])

  const toLogicalDelta = useCallback((value: number) => value / scale, [scale])
  const toLogicalPoint = useCallback((x: number, y: number) => ({ x: x / scale, y: y / scale }), [scale])
  const value = useMemo(() => ({ scale, display, toLogicalDelta, toLogicalPoint }), [display, scale, toLogicalDelta, toLogicalPoint])

  return <Win31ScaleContext.Provider value={value}>{children}</Win31ScaleContext.Provider>
}

export function useWin31Scale(): Win31ScaleValue {
  return useContext(Win31ScaleContext)
}
