import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type JSX,
  type ReactNode
} from 'react'
import { useProgramStore } from '@/store/programStore'
import { useUIStore } from '@/store/uiStore'
import { routeWin95Shortcut, type Win95InputLayer } from './shellInput'
import { useWin95WindowStore } from './windowStore'

export type Win95KeyHandler = (event: KeyboardEvent) => boolean
export type Win95PointerPhase = 'pointerdown' | 'pointermove' | 'pointerup'
export type Win95PointerHandler = (event: PointerEvent) => boolean

interface Win95InputControllerValue {
  startMenuOpen: boolean
  openStartMenu: () => void
  closeStartMenu: () => void
  toggleStartMenu: () => void
  registerKeyHandler: (layer: Win95InputLayer, id: string, handler: Win95KeyHandler) => () => void
  registerPointerHandler: (phase: Win95PointerPhase, id: string, handler: Win95PointerHandler) => () => void
  setMenuScopeOpen: (id: string, open: boolean) => void
}

const noop = (): void => undefined
const Win95InputControllerContext = createContext<Win95InputControllerValue>({
  startMenuOpen: false,
  openStartMenu: noop,
  closeStartMenu: noop,
  toggleStartMenu: noop,
  registerKeyHandler: () => noop,
  registerPointerHandler: () => noop,
  setMenuScopeOpen: noop
})

const LAYERS: Win95InputLayer[] = ['modal', 'menu', 'window', 'desktop']

export function Win95InputControllerProvider({ children }: { children: ReactNode }): JSX.Element {
  const activeDialog = useUIStore((state) => state.activeDialog)
  const quickSearchOpen = useUIStore((state) => state.quickSearchOpen)
  const openDialog = useUIStore((state) => state.openDialog)
  const openQuickSearch = useUIStore((state) => state.openQuickSearch)
  const groups = useProgramStore((state) => state.groups)
  const updateGroupWindowState = useProgramStore((state) => state.updateGroupWindowState)
  const openMyComputer = useWin95WindowStore((state) => state.openMyComputer)
  const [startMenuOpen, setStartMenuOpen] = useState(false)
  const keyHandlers = useRef(new Map<Win95InputLayer, Map<string, Win95KeyHandler>>(
    LAYERS.map((layer) => [layer, new Map()])
  ))
  const pointerHandlers = useRef(new Map<Win95PointerPhase, Map<string, Win95PointerHandler>>([
    ['pointerdown', new Map()], ['pointermove', new Map()], ['pointerup', new Map()]
  ]))
  const menuScopes = useRef(new Set<string>())
  const modifierPending = useRef<'Alt' | 'Meta' | null>(null)

  const closeStartMenu = useCallback(() => setStartMenuOpen(false), [])
  const openStartMenu = useCallback(() => setStartMenuOpen(true), [])
  const toggleStartMenu = useCallback(() => setStartMenuOpen((open) => !open), [])

  const registerKeyHandler = useCallback((layer: Win95InputLayer, id: string, handler: Win95KeyHandler) => {
    const handlers = keyHandlers.current.get(layer)
    handlers?.set(id, handler)
    return () => { if (handlers?.get(id) === handler) handlers.delete(id) }
  }, [])
  const registerPointerHandler = useCallback((phase: Win95PointerPhase, id: string, handler: Win95PointerHandler) => {
    const handlers = pointerHandlers.current.get(phase)
    handlers?.set(id, handler)
    return () => { if (handlers?.get(id) === handler) handlers.delete(id) }
  }, [])
  const setMenuScopeOpen = useCallback((id: string, open: boolean) => {
    if (open) menuScopes.current.add(id)
    else menuScopes.current.delete(id)
  }, [])

  const dispatchLayer = useCallback((layer: Win95InputLayer, event: KeyboardEvent): boolean => {
    const handlers = [...(keyHandlers.current.get(layer)?.values() ?? [])].reverse()
    for (const handler of handlers) if (handler(event)) return true
    return false
  }, [])

  const cycleWindow = useCallback((reverse: boolean): void => {
    const state = useWin95WindowStore.getState()
    const ordered = [...state.windows].sort((a, b) => a.zIndex - b.zIndex)
    if (!ordered.length) return
    const active = ordered.findIndex((entry) => entry.id === state.activeWindowId)
    const delta = reverse ? -1 : 1
    const index = active < 0 ? (reverse ? ordered.length - 1 : 0) : (active + delta + ordered.length) % ordered.length
    const entry = ordered[index]
    if (entry.kind === 'group' && entry.groupId) updateGroupWindowState(entry.groupId, { minimized: false }, 'win95')
    else state.updateSystemWindow(entry.id, { systemMinimized: false })
    state.focusWindow(entry.id)
  }, [updateGroupWindowState])

  useEffect(() => {
    const keydown = (event: KeyboardEvent): void => {
      if (event.defaultPrevented) return
      if (event.key === 'Alt' && !event.ctrlKey && !event.shiftKey && !event.metaKey) modifierPending.current = 'Alt'
      else if (event.key === 'Meta' && !event.ctrlKey && !event.shiftKey && !event.altKey) modifierPending.current = 'Meta'
      else if (event.altKey || event.metaKey) modifierPending.current = null

      // Modal-owned keyboard loops are registered separately and are the only
      // recipients while a modal is present. quickSearchOpen is treated as a
      // modal until Find becomes a primary window.
      if (activeDialog !== null || quickSearchOpen) {
        if (dispatchLayer('modal', event)) { event.preventDefault(); event.stopImmediatePropagation() }
        return
      }

      const command = routeWin95Shortcut(event)
      if (command) {
        let handled = true
        if (command === 'toggle-start') toggleStartMenu()
        else if (command === 'open-run') { closeStartMenu(); openDialog('run') }
        else if (command === 'open-find') { closeStartMenu(); openQuickSearch() }
        else if (command === 'open-explorer') { closeStartMenu(); openMyComputer() }
        else if (command === 'cycle-window' || command === 'cycle-window-reverse') cycleWindow(command === 'cycle-window-reverse')
        else if (command === 'system-menu' || command === 'close-window') handled = dispatchLayer('window', event)
        else if (command === 'context-menu') handled = dispatchLayer('menu', event) || dispatchLayer('window', event) || dispatchLayer('desktop', event)
        else handled = false
        if (handled) { event.preventDefault(); event.stopImmediatePropagation() }
        return
      }

      const menuIsOpen = startMenuOpen || menuScopes.current.size > 0
      const handled = (menuIsOpen && dispatchLayer('menu', event)) ||
        dispatchLayer('window', event) || dispatchLayer('desktop', event)
      if (handled) { event.preventDefault(); event.stopImmediatePropagation() }
    }
    const keyup = (event: KeyboardEvent): void => {
      if (event.defaultPrevented || activeDialog !== null || quickSearchOpen) return
      if (event.key === 'Meta' && modifierPending.current === 'Meta') {
        modifierPending.current = null
        toggleStartMenu(); event.preventDefault(); event.stopImmediatePropagation(); return
      }
      if (event.key === 'Alt' && modifierPending.current === 'Alt') {
        modifierPending.current = null
        closeStartMenu()
        const synthetic = new KeyboardEvent('keydown', { key: 'Alt' })
        if (dispatchLayer('window', synthetic)) { event.preventDefault(); event.stopImmediatePropagation() }
      }
    }
    window.addEventListener('keydown', keydown)
    window.addEventListener('keyup', keyup)
    return () => {
      window.removeEventListener('keydown', keydown)
      window.removeEventListener('keyup', keyup)
    }
  }, [activeDialog, closeStartMenu, cycleWindow, dispatchLayer, openDialog, openMyComputer, openQuickSearch, quickSearchOpen, startMenuOpen, toggleStartMenu])

  useEffect(() => {
    const listeners = (['pointerdown', 'pointermove', 'pointerup'] as Win95PointerPhase[]).map((phase) => {
      const listener = (event: PointerEvent): void => {
        const handlers = [...(pointerHandlers.current.get(phase)?.values() ?? [])].reverse()
        for (const handler of handlers) if (handler(event)) break
      }
      document.addEventListener(phase, listener)
      return { phase, listener }
    })
    return () => listeners.forEach(({ phase, listener }) => document.removeEventListener(phase, listener))
  }, [])

  // Groups are read here so the provider tracks store replacement/migrations;
  // shortcut handlers themselves always use the latest store state.
  void groups

  const value = useMemo<Win95InputControllerValue>(() => ({
    startMenuOpen,
    openStartMenu,
    closeStartMenu,
    toggleStartMenu,
    registerKeyHandler,
    registerPointerHandler,
    setMenuScopeOpen
  }), [closeStartMenu, openStartMenu, registerKeyHandler, registerPointerHandler, setMenuScopeOpen, startMenuOpen, toggleStartMenu])
  return <Win95InputControllerContext.Provider value={value}>{children}</Win95InputControllerContext.Provider>
}

export function useWin95InputController(): Win95InputControllerValue {
  return useContext(Win95InputControllerContext)
}

export function useWin95InputHandler(layer: Win95InputLayer, id: string, handler: Win95KeyHandler, enabled = true): void {
  const { registerKeyHandler } = useWin95InputController()
  const handlerRef = useRef(handler)
  handlerRef.current = handler
  useEffect(() => {
    if (!enabled) return
    return registerKeyHandler(layer, id, (event) => handlerRef.current(event))
  }, [enabled, id, layer, registerKeyHandler])
}

export function useWin95PointerHandler(phase: Win95PointerPhase, id: string, handler: Win95PointerHandler, enabled = true): void {
  const { registerPointerHandler } = useWin95InputController()
  const handlerRef = useRef(handler)
  handlerRef.current = handler
  useEffect(() => {
    if (!enabled) return
    return registerPointerHandler(phase, id, (event) => handlerRef.current(event))
  }, [enabled, id, phase, registerPointerHandler])
}

export function useWin95MenuScope(id: string, open: boolean): void {
  const { setMenuScopeOpen } = useWin95InputController()
  useEffect(() => {
    setMenuScopeOpen(id, open)
    return () => setMenuScopeOpen(id, false)
  }, [id, open, setMenuScopeOpen])
}
