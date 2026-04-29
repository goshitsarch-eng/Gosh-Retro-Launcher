import type { ShellType } from '@shared/types'

export interface ShellProps {
  platform: string
}

export interface ShellPreviewFixture {
  desktop: string
  windowBg: string
  chrome: string
  bevelLight: string
  bevelDark: string
  bevelDarkest: string
  titlebarActive: string
  titlebarInactive: string
  titlebarText: string
  titlebarGradientEnd?: string
  text: string
  accent?: string
}

export interface ShellDesignContract {
  cssScope: `shell-${ShellType}`
  desktop: 'mdi-program-manager' | 'desktop-taskbar'
  windowFrame: 'win31-flat' | 'win95-explorer'
  menu: 'win31-menubar' | 'win95-start-menu'
  dialog: 'win31-modal' | 'win95-modal'
  iconGrid: 'program-manager' | 'explorer-desktop'
  sounds: 'win31' | 'win95'
  preview: {
    light: ShellPreviewFixture
    dark: ShellPreviewFixture
  }
  futureTargets?: string[]
}

export interface ShellDefinition {
  id: ShellType
  name: string
  component: React.ComponentType<ShellProps>
  design: ShellDesignContract
}
