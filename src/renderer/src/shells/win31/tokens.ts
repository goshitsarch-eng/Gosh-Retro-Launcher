import { WIN31_SCALE_FACTORS, isWin31ScalePreference, type Win31ScalePreference } from '@shared/types'

export const WFW_REFERENCE_WIDTH = 640
export const WFW_REFERENCE_HEIGHT = 480
export const WFW_SCALE_FACTORS = WIN31_SCALE_FACTORS

export type WfwScaleFactor = (typeof WFW_SCALE_FACTORS)[number]
export type WfwScalePreference = Win31ScalePreference

/**
 * Logical-pixel measurements taken from the supplied WfW 3.11 captures.
 * Rendering scales these values only at the root Win31 boundary.
 */
export const WFW_METRICS = {
  outerFrame: 3,
  captionHeight: 18,
  menuHeight: 20,
  menuLeftInset: 6,
  menuGap: 17,
  childFrame: 3,
  childCaptionHeight: 18,
  captionButton: 16,
  scrollbar: 16,
  programIcon: 32,
  programCellWidth: 75,
  programCellHeight: 72,
  programGridInsetX: 0,
  programGridInsetY: 0,
  groupIconWidth: 32,
  groupIconHeight: 25,
  groupCellWidth: 75,
  groupCellHeight: 58,
  labelLineHeight: 13,
  dialogControlHeight: 22
} as const

export const WFW_PALETTE = {
  black: '#000000',
  shadow: '#808080',
  face: '#c0c0c0',
  white: '#ffffff',
  navy: '#000080',
  green: '#008000',
  teal: '#008080',
  maroon: '#800000',
  purple: '#800080',
  olive: '#808000',
  red: '#ff0000',
  lime: '#00ff00',
  yellow: '#ffff00',
  blue: '#0000ff',
  aqua: '#00ffff',
  fuchsia: '#ff00ff'
} as const

export function resolveWfwAutoScale(
  workAreaWidth: number,
  workAreaHeight: number
): WfwScaleFactor {
  const fitted = Math.floor(
    Math.min(workAreaWidth / WFW_REFERENCE_WIDTH, workAreaHeight / WFW_REFERENCE_HEIGHT)
  )
  return Math.max(1, Math.min(4, fitted)) as WfwScaleFactor
}

export const isWfwScalePreference = isWin31ScalePreference
