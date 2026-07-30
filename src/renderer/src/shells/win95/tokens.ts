export const WIN95_REFERENCE_WIDTH = 640
export const WIN95_REFERENCE_HEIGHT = 480
export const WIN95_SCALE_FACTORS = [1, 2, 3, 4] as const

export type Win95ScaleFactor = (typeof WIN95_SCALE_FACTORS)[number]

/**
 * Logical-pixel measurements from a clean Windows 95 RTM retail installation
 * using the default 640×480/96-DPI appearance. Values are never multiplied in
 * components; the Win95 root owns the one integer transform.
 */
export const WIN95_METRICS = {
  taskbarHeight: 28,
  taskbarTopHighlight: 1,
  taskbarInset: 2,
  startButtonWidth: 54,
  startButtonHeight: 22,
  startButtonIcon: 16,
  taskButtonHeight: 22,
  taskButtonMaxWidth: 160,
  trayHeight: 22,
  trayWidth: 63,
  trayMinWidth: 63,
  desktopIcon: 32,
  desktopCellWidth: 75,
  desktopCellHeight: 74,
  desktopInsetX: 4,
  desktopInsetY: 4,
  smallIcon: 16,
  largeIcon: 32,
  startTopIcon: 32,
  startTopItemHeight: 32,
  startSubIcon: 16,
  startSubItemHeight: 22,
  startStripWidth: 21,
  startMenuWidth: 164,
  startMenuHeight: 235,
  startSeparatorHeight: 7,
  menuBorder: 2,
  menuHorizontalInset: 3,
  menuSeparatorHeight: 6,
  windowFrame: 3,
  captionHeight: 18,
  captionInset: 2,
  captionButton: 16,
  captionButtonWidth: 16,
  captionButtonHeight: 14,
  captionButtonGap: 2,
  menuBarHeight: 20,
  statusBarHeight: 20,
  scrollbar: 16,
  resizeBorder: 3,
  dialogFrame: 3,
  dialogCaptionHeight: 18,
  buttonHeight: 23,
  buttonMinWidth: 75,
  inputHeight: 21,
  runDialogWidth: 347,
  runDialogHeight: 163,
  shutdownDialogWidth: 347,
  shutdownDialogHeight: 222,
  findWindowWidth: 439,
  findWindowHeight: 237,
  labelLineHeight: 13,
  systemFontPx: 11,
  submenuDelayMs: 220,
  doubleClickMs: 500
} as const

export const WIN95_PALETTE = {
  desktop: '#008080',
  face: '#c0c0c0',
  light: '#ffffff',
  highlight: '#dfdfdf',
  shadow: '#808080',
  darkShadow: '#000000',
  window: '#ffffff',
  text: '#000000',
  disabledText: '#808080',
  disabledHighlight: '#ffffff',
  activeCaption: '#000080',
  inactiveCaption: '#808080',
  captionText: '#ffffff',
  inactiveCaptionText: '#c0c0c0',
  selection: '#000080',
  selectionText: '#ffffff'
} as const

export function resolveWin95AutoScale(width: number, height: number): Win95ScaleFactor {
  const safeWidth = Number.isFinite(width) ? Math.max(0, width) : 0
  const safeHeight = Number.isFinite(height) ? Math.max(0, height) : 0
  const fit = Math.floor(Math.min(
    safeWidth / WIN95_REFERENCE_WIDTH,
    safeHeight / WIN95_REFERENCE_HEIGHT
  ))
  return Math.max(1, Math.min(4, fit)) as Win95ScaleFactor
}

export function toWin95LogicalDelta(physicalDelta: number, scale: Win95ScaleFactor): number {
  return physicalDelta / scale
}

export function toWin95LogicalPoint(
  clientX: number,
  clientY: number,
  scale: Win95ScaleFactor,
  origin: { left: number; top: number } = { left: 0, top: 0 }
): { x: number; y: number } {
  return { x: (clientX - origin.left) / scale, y: (clientY - origin.top) / scale }
}

export function resolveWin95RasterVariant(
  scale: Win95ScaleFactor,
  devicePixelRatio: number,
  maximumVariant = 4
): 1 | 2 | 3 | 4 {
  const dpr = Number.isFinite(devicePixelRatio) ? Math.max(1, devicePixelRatio) : 1
  return Math.max(1, Math.min(maximumVariant, Math.ceil(scale * dpr))) as 1 | 2 | 3 | 4
}

export function logicalViewportSize(
  physicalWidth: number,
  physicalHeight: number,
  scale: Win95ScaleFactor
): { width: number; height: number } {
  return {
    width: Math.max(1, Math.ceil(physicalWidth / scale)),
    height: Math.max(1, Math.ceil(physicalHeight / scale))
  }
}
