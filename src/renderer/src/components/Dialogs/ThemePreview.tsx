import React from 'react'
import { getShell } from '@/shells'
import type { ShellPreviewFixture } from '@/shells/types'
import type { ShellType } from '@shared/types'

interface ThemePreviewProps {
  shell: ShellType
  theme: 'light' | 'dark'
  groupChromeScale: number
}

export const ThemePreview: React.FC<ThemePreviewProps> = ({
  shell,
  theme,
  groupChromeScale
}) => {
  const shellDef = getShell(shell)
  const colors = shellDef?.design.preview[theme]

  if (!shellDef || !colors) return null

  if (shellDef.design.desktop === 'desktop-taskbar') {
    return <Win95Preview colors={colors} groupChromeScale={groupChromeScale} />
  }

  return <Win31Preview colors={colors} groupChromeScale={groupChromeScale} />
}

function Win31Preview({
  colors,
  groupChromeScale
}: {
  colors: ShellPreviewFixture
  groupChromeScale: number
}): React.ReactElement {
  const titleH = Math.round(17 * groupChromeScale)

  return (
    <div className="theme-preview theme-preview-win31" style={{ background: colors.desktop }}>
      <div className="theme-preview-win31-title" style={{ background: colors.chrome, color: colors.text }}>
        Program Manager
      </div>
      <div className="theme-preview-menubar" style={{ background: colors.chrome, color: colors.text }}>
        <span>File</span>
        <span>Options</span>
        <span>Window</span>
        <span>Help</span>
      </div>
      <div
        className="theme-preview-window"
        style={{
          background: colors.chrome,
          borderColor: colors.bevelDarkest,
          boxShadow: `inset 1px 1px 0 ${colors.bevelLight}, inset -1px -1px 0 ${colors.bevelDark}`
        }}
      >
        <div
          className="theme-preview-titlebar"
          style={{
            height: titleH,
            background: colors.titlebarActive,
            color: colors.titlebarText
          }}
        >
          Main
          <span />
        </div>
        <div className="theme-preview-body" style={{ background: colors.windowBg }}>
          <i style={{ background: colors.titlebarActive }} />
          <i style={{ background: colors.titlebarInactive }} />
          <i style={{ background: colors.bevelDark }} />
        </div>
      </div>
      <div className="theme-preview-minimized" style={{ color: colors.titlebarText }}>
        Accessories
      </div>
    </div>
  )
}

function Win95Preview({
  colors,
  groupChromeScale
}: {
  colors: ShellPreviewFixture
  groupChromeScale: number
}): React.ReactElement {
  const titleH = Math.round(18 * groupChromeScale)
  const titleBackground = `linear-gradient(to right, ${colors.titlebarActive}, ${colors.titlebarGradientEnd ?? colors.titlebarActive})`

  return (
    <div className="theme-preview theme-preview-win95" style={{ background: colors.desktop }}>
      <div className="theme-preview-desktop-icons" style={{ color: colors.titlebarText }}>
        <i style={{ background: colors.chrome }} />
        <span>My Computer</span>
      </div>
      <div
        className="theme-preview-window theme-preview-win95-window"
        style={{
          background: colors.chrome,
          borderTopColor: colors.bevelLight,
          borderLeftColor: colors.bevelLight,
          borderBottomColor: colors.bevelDarkest,
          borderRightColor: colors.bevelDarkest
        }}
      >
        <div
          className="theme-preview-titlebar"
          style={{
            height: titleH,
            background: titleBackground,
            color: colors.titlebarText
          }}
        >
          Programs
          <span />
        </div>
        <div className="theme-preview-toolbar" style={{ background: colors.chrome, color: colors.text }}>
          File Edit View
        </div>
        <div className="theme-preview-body" style={{ background: colors.windowBg }}>
          <i style={{ background: colors.titlebarActive }} />
          <i style={{ background: colors.accent ?? colors.bevelDark }} />
          <i style={{ background: colors.bevelDark }} />
        </div>
      </div>
      <div className="theme-preview-taskbar" style={{ background: colors.chrome, borderTopColor: colors.bevelLight }}>
        <div
          className="theme-preview-start"
          style={{
            color: colors.text,
            borderTopColor: colors.bevelLight,
            borderLeftColor: colors.bevelLight,
            borderBottomColor: colors.bevelDarkest,
            borderRightColor: colors.bevelDarkest
          }}
        >
          Start
        </div>
        <div className="theme-preview-tray" style={{ color: colors.text }}>
          3:11 PM
        </div>
      </div>
    </div>
  )
}
