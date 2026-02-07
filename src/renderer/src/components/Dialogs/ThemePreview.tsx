import React from 'react'
import type { ShellType } from '@shared/types'

interface ThemePreviewProps {
  shell: ShellType
  theme: 'light' | 'dark'
  groupChromeScale: number
}

const LIGHT_COLORS = {
  desktop: '#008080',
  windowBg: '#ffffff',
  chrome: '#c0c0c0',
  bevelLight: '#ffffff',
  bevelDark: '#808080',
  bevelDarkest: '#000000',
  titlebarActive: '#000080',
  titlebarText: '#ffffff',
  text: '#000000',
  titlebarGradientEnd: '#1084d0',
  taskbarBorder: '#ffffff'
}

const DARK_COLORS = {
  desktop: '#0f2f2f',
  windowBg: '#1f1f1f',
  chrome: '#2b2b2b',
  bevelLight: '#4a4a4a',
  bevelDark: '#101010',
  bevelDarkest: '#000000',
  titlebarActive: '#0b2a52',
  titlebarText: '#e6e6e6',
  text: '#e6e6e6',
  titlebarGradientEnd: '#1a5a8c',
  taskbarBorder: '#4a4a4a'
}

export const ThemePreview: React.FC<ThemePreviewProps> = ({ shell, theme, groupChromeScale }) => {
  const c = theme === 'dark' ? DARK_COLORS : LIGHT_COLORS
  const titleH = Math.round(18 * groupChromeScale)

  if (shell === 'win95') {
    return (
      <div
        style={{
          width: '100%',
          height: 100,
          background: c.desktop,
          borderRadius: 2,
          position: 'relative',
          overflow: 'hidden',
          border: `1px solid ${c.bevelDarkest}`,
          display: 'flex',
          flexDirection: 'column'
        }}
      >
        {/* Window */}
        <div
          style={{
            position: 'absolute',
            top: 6,
            left: 12,
            width: '65%',
            height: 58,
            background: c.chrome,
            border: `2px solid ${c.bevelDarkest}`,
            borderTopColor: c.bevelLight,
            borderLeftColor: c.bevelLight,
            display: 'flex',
            flexDirection: 'column'
          }}
        >
          {/* Gradient titlebar */}
          <div
            style={{
              height: titleH,
              background: `linear-gradient(to right, ${c.titlebarActive}, ${c.titlebarGradientEnd})`,
              display: 'flex',
              alignItems: 'center',
              padding: '0 3px',
              gap: 3
            }}
          >
            <div
              style={{
                width: 8,
                height: 8,
                background: c.titlebarText,
                opacity: 0.6,
                flexShrink: 0
              }}
            />
            <div
              style={{
                flex: 1,
                height: 6,
                background: c.titlebarText,
                opacity: 0.5,
                borderRadius: 1
              }}
            />
            {/* Control buttons */}
            <div style={{ display: 'flex', gap: 1 }}>
              {['_', '\u25A1', '\u00D7'].map((ch, i) => (
                <div
                  key={i}
                  style={{
                    width: 10,
                    height: 10,
                    background: c.chrome,
                    border: '1px solid',
                    borderColor: `${c.bevelLight} ${c.bevelDarkest} ${c.bevelDarkest} ${c.bevelLight}`,
                    fontSize: 7,
                    lineHeight: '10px',
                    textAlign: 'center',
                    color: c.text
                  }}
                >
                  {ch}
                </div>
              ))}
            </div>
          </div>
          {/* Body */}
          <div
            style={{
              flex: 1,
              margin: 2,
              background: c.windowBg,
              border: `1px solid ${c.bevelDark}`,
              borderBottomColor: c.bevelLight,
              borderRightColor: c.bevelLight
            }}
          />
          {/* Status bar */}
          <div
            style={{
              height: 12,
              margin: '0 2px 2px 2px',
              background: c.chrome,
              border: `1px solid ${c.bevelDark}`,
              borderBottomColor: c.bevelLight,
              borderRightColor: c.bevelLight,
              fontSize: 6,
              lineHeight: '10px',
              paddingLeft: 3,
              color: c.text
            }}
          >
            3 objects
          </div>
        </div>

        {/* Taskbar */}
        <div
          style={{
            position: 'absolute',
            bottom: 0,
            left: 0,
            right: 0,
            height: 18,
            background: c.chrome,
            borderTop: `2px solid ${c.taskbarBorder}`,
            display: 'flex',
            alignItems: 'center',
            padding: '0 3px',
            gap: 3
          }}
        >
          {/* Start button */}
          <div
            style={{
              height: 14,
              padding: '0 4px',
              background: c.chrome,
              border: '1px solid',
              borderColor: `${c.bevelLight} ${c.bevelDarkest} ${c.bevelDarkest} ${c.bevelLight}`,
              fontSize: 7,
              fontWeight: 'bold',
              lineHeight: '14px',
              color: c.text,
              display: 'flex',
              alignItems: 'center',
              gap: 2
            }}
          >
            <div
              style={{
                width: 8,
                height: 8,
                background: `linear-gradient(135deg, #ff0000, #00ff00, #0000ff, #ffff00)`,
                flexShrink: 0
              }}
            />
            Start
          </div>
        </div>
      </div>
    )
  }

  // Win31 preview
  return (
    <div
      style={{
        width: '100%',
        height: 100,
        background: c.desktop,
        borderRadius: 2,
        position: 'relative',
        overflow: 'hidden',
        border: `1px solid ${c.bevelDarkest}`,
        display: 'flex',
        flexDirection: 'column'
      }}
    >
      {/* Menu bar */}
      <div
        style={{
          height: 16,
          background: c.chrome,
          borderBottom: `1px solid ${c.bevelDark}`,
          display: 'flex',
          alignItems: 'center',
          padding: '0 6px',
          gap: 12,
          fontSize: 7,
          color: c.text,
          flexShrink: 0
        }}
      >
        <span>File</span>
        <span>Options</span>
        <span>Window</span>
        <span>Help</span>
      </div>

      {/* MDI Window */}
      <div
        style={{
          position: 'absolute',
          top: 22,
          left: 10,
          width: '60%',
          height: 52,
          background: c.chrome,
          border: `1px solid ${c.bevelDarkest}`
        }}
      >
        {/* Titlebar */}
        <div
          style={{
            height: titleH,
            background: c.titlebarActive,
            display: 'flex',
            alignItems: 'center',
            padding: '0 3px'
          }}
        >
          <div
            style={{
              flex: 1,
              height: 6,
              background: c.titlebarText,
              opacity: 0.5,
              borderRadius: 1
            }}
          />
        </div>
        {/* Body */}
        <div
          style={{
            position: 'absolute',
            top: titleH + 1,
            left: 2,
            right: 2,
            bottom: 2,
            background: c.windowBg,
            border: `1px solid ${c.bevelDark}`
          }}
        />
      </div>
    </div>
  )
}
