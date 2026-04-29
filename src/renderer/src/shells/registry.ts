import type { ShellType } from '@shared/types'
import type { ShellDefinition } from './types'
import { Win31Shell } from './Win31Shell'
import { Win95Shell } from './win95'

const shells = new Map<ShellType, ShellDefinition>()

export function registerShell(shell: ShellDefinition): void {
  shells.set(shell.id, shell)
}

export function getShell(id: ShellType): ShellDefinition | undefined {
  return shells.get(id)
}

export function getAllShells(): ShellDefinition[] {
  return Array.from(shells.values())
}

// Register built-in shells
registerShell({
  id: 'win31',
  name: 'Windows 3.1',
  component: Win31Shell,
  design: {
    cssScope: 'shell-win31',
    desktop: 'mdi-program-manager',
    windowFrame: 'win31-flat',
    menu: 'win31-menubar',
    dialog: 'win31-modal',
    iconGrid: 'program-manager',
    sounds: 'win31',
    futureTargets: ['beos', 'macos9'],
    preview: {
      light: {
        desktop: '#008080',
        windowBg: '#ffffff',
        chrome: '#c0c0c0',
        bevelLight: '#ffffff',
        bevelDark: '#808080',
        bevelDarkest: '#000000',
        titlebarActive: '#000080',
        titlebarInactive: '#808080',
        titlebarText: '#ffffff',
        text: '#000000'
      },
      dark: {
        desktop: '#0f2f2f',
        windowBg: '#1f1f1f',
        chrome: '#2b2b2b',
        bevelLight: '#4a4a4a',
        bevelDark: '#101010',
        bevelDarkest: '#000000',
        titlebarActive: '#0b2a52',
        titlebarInactive: '#3a3a3a',
        titlebarText: '#e6e6e6',
        text: '#e6e6e6'
      }
    }
  }
})

registerShell({
  id: 'win95',
  name: 'Windows 95',
  component: Win95Shell,
  design: {
    cssScope: 'shell-win95',
    desktop: 'desktop-taskbar',
    windowFrame: 'win95-explorer',
    menu: 'win95-start-menu',
    dialog: 'win95-modal',
    iconGrid: 'explorer-desktop',
    sounds: 'win95',
    futureTargets: ['beos', 'macos9'],
    preview: {
      light: {
        desktop: '#008080',
        windowBg: '#ffffff',
        chrome: '#c0c0c0',
        bevelLight: '#ffffff',
        bevelDark: '#808080',
        bevelDarkest: '#000000',
        titlebarActive: '#000080',
        titlebarInactive: '#808080',
        titlebarText: '#ffffff',
        titlebarGradientEnd: '#1084d0',
        text: '#000000',
        accent: '#ff0000'
      },
      dark: {
        desktop: '#0f2f2f',
        windowBg: '#1f1f1f',
        chrome: '#2b2b2b',
        bevelLight: '#4a4a4a',
        bevelDark: '#101010',
        bevelDarkest: '#000000',
        titlebarActive: '#0b2a52',
        titlebarInactive: '#3a3a3a',
        titlebarText: '#e6e6e6',
        titlebarGradientEnd: '#1a5a8c',
        text: '#e6e6e6',
        accent: '#b0b0b0'
      }
    }
  }
})
