import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createShellWindowState, DEFAULT_SETTINGS, DEFAULT_WINDOW_STATE, getGroupWindowState, type ProgramGroup } from '@shared/types'
import { useProgramStore } from '../../../store/programStore'
import { useWin95WindowStore } from '../windowStore'

function group(id: string): ProgramGroup {
  return {
    id,
    name: id,
    icon: 'folder',
    windowState: { ...DEFAULT_WINDOW_STATE },
    shellWindowState: createShellWindowState(),
    items: []
  }
}

describe('Win95 primary-window store', () => {
  beforeEach(() => {
    useProgramStore.setState({ groups: [group('one'), group('two')], settings: { ...DEFAULT_SETTINGS, shell: 'win95', saveSettingsOnExit: false } })
    useWin95WindowStore.getState().reset()
  })
  afterEach(() => useWin95WindowStore.getState().reset())

  it('reactivates a single group instance and restores it before focus', () => {
    useWin95WindowStore.getState().openGroup('one')
    useWin95WindowStore.getState().openGroup('one')
    expect(useWin95WindowStore.getState().windows).toHaveLength(1)
    useProgramStore.getState().updateGroupWindowState('one', { minimized: true }, 'win95')
    useWin95WindowStore.getState().activateDesktop()
    useWin95WindowStore.getState().focusWindow('group:one')
    expect(useWin95WindowStore.getState().activeWindowId).toBeNull()
    useWin95WindowStore.getState().openGroup('one')
    expect(getGroupWindowState(useProgramStore.getState().groups[0], 'win95').minimized).toBe(false)
    expect(useWin95WindowStore.getState().activeWindowId).toBe('group:one')
  })

  it('never chooses a minimized window when deactivating or closing', () => {
    const state = useWin95WindowStore.getState()
    state.openGroup('one')
    state.openGroup('two')
    useProgramStore.getState().updateGroupWindowState('one', { minimized: true }, 'win95')
    state.deactivateWindow('group:two')
    expect(useWin95WindowStore.getState().activeWindowId).toBeNull()
    state.openMyComputer()
    state.closeWindow('my-computer')
    expect(useWin95WindowStore.getState().activeWindowId).toBe('group:two')
  })

  it('opens Find and My Computer as independent single-instance tasks', () => {
    const state = useWin95WindowStore.getState()
    state.openFind(); state.openFind(); state.openMyComputer(); state.openMyComputer()
    expect(useWin95WindowStore.getState().windows.map((entry) => entry.id)).toEqual(['find', 'my-computer'])
    expect(useWin95WindowStore.getState().windows.find((entry) => entry.id === 'find')?.systemBounds)
      .toEqual({ x: 96, y: 58, width: 439, height: 237 })
  })

  it('routes one-shot Move/Size requests to the target id', () => {
    const state = useWin95WindowStore.getState()
    state.openMyComputer(); state.requestWindowCommand('my-computer', 'size')
    const request = useWin95WindowStore.getState().requestedCommand
    expect(request).toMatchObject({ id: 'my-computer', command: 'size' })
    state.clearWindowCommand(request!.nonce)
    expect(useWin95WindowStore.getState().requestedCommand).toBeNull()
  })
})
