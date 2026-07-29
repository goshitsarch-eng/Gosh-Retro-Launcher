import type { ProgramGroup } from '@shared/types'

/**
 * Deterministic visual-test data matching the supplied WfW Program Manager
 * capture. This module is never imported by the user store and must not be
 * used as first-run seed data.
 */
export const WFW_PROGRAM_MANAGER_FIXTURE: ProgramGroup[] = [
  {
    id: 'fixture-main',
    name: 'Main',
    icon: 'wfw-group',
    windowState: { x: 0, y: 0, width: 416, height: 201, minimized: false, maximized: false },
    shellWindowState: {
      win31: { x: 0, y: 0, width: 416, height: 201, minimized: false, maximized: false },
      win95: { x: 20, y: 20, width: 416, height: 201, minimized: false, maximized: false }
    },
    win31IconPosition: { x: 300, y: 219 },
    items: [
      ['File Manager', 'wfw-file-manager'],
      ['Control Panel', 'wfw-control-panel'],
      ['Print Manager', 'wfw-print-manager'],
      ['ClipBook Viewer', 'wfw-clipbook'],
      ['MS-DOS Prompt', 'wfw-dos'],
      ['Windows Setup', 'wfw-setup'],
      ['PIF Editor', 'wfw-pif'],
      ['Read Me', 'wfw-readme']
    ].map(([name, icon], index) => ({
      id: `fixture-main-${index}`,
      name,
      path: '',
      icon,
      workingDir: '',
      win31Position: { x: (index % 5) * 75, y: Math.floor(index / 5) * 72 }
    }))
  },
  ...['Accessories', 'Network', 'Games', 'StartUp'].map((name, index): ProgramGroup => ({
    id: `fixture-${name.toLowerCase()}`,
    name,
    icon: 'wfw-group',
    windowState: { x: 20, y: 20, width: 300, height: 200, minimized: true, maximized: false },
    shellWindowState: {
      win31: { x: 20, y: 20, width: 300, height: 200, minimized: true, maximized: false },
      win95: { x: 20, y: 20, width: 300, height: 200, minimized: true, maximized: false }
    },
    win31IconPosition: { x: index * 75, y: 219 },
    items: []
  }))
]
