// Default icons as embedded data URLs (Win 3.1 style 32x32 icons)

// Default program icon - simple document/app icon
export const DEFAULT_ITEM_ICON =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAA7AAAAOwBeShxvQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAEKSURBVFiF7ZaxTsMwEIa/OyeFgYGJgYmBiQFegQdgZGRkZOANeAQegZGRkYGJgYmBCQYkBgY6kBDEkCZxfLbvIlL1W07y+e7/bN8ZLiyMBbAAcM4NAL6f/0t0nAF8AjaA0+eG4OMAuwDAEPAD4AToA3wB+grcBDgC2Ab8BHgBPgCugQ8ArwG+/A0eAO4BvP8Y+NW5BPAKsAXwCHAHcBvg3f/w6QC4BXj6G/QL0C7AHUAnwI2/IYcnFwC3AB3/F6/+Hb/5OwA+An0BugU4BrgD2AS4+C+kRNftAN/AOcApwD3AJcAtwA7Ayb+h+2e/8he4B+gU4AHgHOAM4B6gE+DUvyHVcVPg+xfWvHVLCLNZQQAAAABJRU5ErkJggg=='

// Folder icon for groups
export const DEFAULT_FOLDER_ICON =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAA7AAAAOwBeShxvQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAADxSURBVFiF7ZYxDoJAEEX/LBZaWFhYWNjY2HgBruAFPIKX8AhewSN4BC9gY2NjYWFhYSFFoYWFBcYCWDALu7KLJPxqMpP3Z2Y3uwADA/8GYSBekohYewMALAEcAFQBzAFsAZz6CnABMAEw82dUDzPPIogIa4AFgDWAFYBKnwEsQ4K0TQAMAIwBHAFMfY1hngBJPIkEEacEKQOYAJgBOPgawzwxJUhX4wmAMoBdX2OYJ6YE6Wo8AzAFcPQ1hnliqgTpOpZJkD2AM4C9rzHMEzOCVMVjw5Qg3wFofY1hnhgR5FcxIchvAJSuxp+APwT/AAN/hxcwY1XN3u3T9gAAAABJRU5ErkJggg=='

// Question mark icon for dialogs
export const QUESTION_ICON =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAA7AAAAOwBeShxvQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAEhSURBVFiF7ZaxTsNADIZ/O5cODAyMDIyMjAy8Ag/AyMjIyMAb8Ag8AiMjIwMjAxMDEgMDHUgIEkNyie1zLkLwW07y+e7+z/adgYaGf4MIEvEkEhE7BwAeAE4ArACsAWwArPsqcAngBMCZPyN7WHgWgUSsAJwDWAG4ALDqK4BlSJC2CYABgAmAPYCFrxHME1OCVMUjwxQgewAXAPu+RjBPTAlSFU8MTADs+hrBPDEiSNUzTIJcArhwGsE8MSJIVTwxTAlyArD2NYJ5YkSQqudYJUHOABa+RjBPjAhS9TyrJMgawNLXCOaJEUGq4qFpSpADgJWvEcwTU4J0xUPTlCAHAAtfI5gnpgTpioemaUqQqnhseiZBquKxaUSQqnhomibI/8MHv2FTwbKqWqgAAAAASUVORK5CYII='

// App icon for Program Manager
export const APP_ICON =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAA7AAAAOwBeShxvQAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAFVSURBVFiF7Za9TsNADMf/vpAODAyMjIyMDLwCD8DIyMjIwBvwCDwCIyMjAyMDEwMSAwMdSAgSQ/Jh+5wLqPAtJ/l89392fGegpua/IIzES5KI2DkA8ApgD+AE4BzADsC6qwJXAE4AnPszqoelZxFIxAnAGYATgEsAJ10FMAwJ0jQB0AcwBXAAsPQ1gnliSpCqeGCaEmQK4NLXCOaJKUGq4pFhSpATgEtfI5gnRgSpeoZJkEsAF04jmCdGBKl6hkmQUwBLXyOYJ0YEqYonhilBLgEsfI1gnhgRpOoZJkEuASx8jWCeGBGkKp6YJgQ5A1j4GsE8MSVIUzwxTQlyBLDwNYJ5YkqQpnhiGhLkGGDhawTzxJQgTfHYNCHIEcCxrxHME1OCNMVj05Agx75GME9MCdIUj01TghwBLHyNYJ6YEqRWPLdMCFIrnltGBKkVzy0TgtSK55YRQX4D/gvv4Ft+TaoAAAAASUVORK5CYII='

// Helper to create simple SVG icons with URL encoding
function createSvgIcon(bgColor: string, content: string): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><rect width="32" height="32" fill="${bgColor}"/>${content}</svg>`
  return `data:image/svg+xml,${encodeURIComponent(svg)}`
}

// Web/Globe icon
const WEB_ICON = createSvgIcon('#000080',
  '<circle cx="16" cy="16" r="10" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<ellipse cx="16" cy="16" rx="4" ry="10" fill="none" stroke="#fff" stroke-width="1.5"/>' +
  '<line x1="6" y1="16" x2="26" y2="16" stroke="#fff" stroke-width="1.5"/>'
)

// Music/Note icon
const MUSIC_ICON = createSvgIcon('#800080',
  '<circle cx="10" cy="22" r="4" fill="#fff"/>' +
  '<circle cx="22" cy="20" r="4" fill="#fff"/>' +
  '<rect x="13" y="8" width="2" height="14" fill="#fff"/>' +
  '<rect x="25" y="6" width="2" height="14" fill="#fff"/>' +
  '<rect x="13" y="6" width="14" height="3" fill="#fff"/>'
)

// Video/Film icon
const VIDEO_ICON = createSvgIcon('#808000',
  '<rect x="4" y="8" width="24" height="16" rx="2" fill="#c0c0c0" stroke="#000"/>' +
  '<polygon points="13,12 21,16 13,20" fill="#000"/>'
)

// Game/Controller icon
const GAME_ICON = createSvgIcon('#008000',
  '<rect x="4" y="10" width="24" height="12" rx="6" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="8" y="14" width="2" height="4" fill="#000"/>' +
  '<rect x="6" y="16" width="6" height="2" fill="#000"/>' +
  '<circle cx="22" cy="14" r="2" fill="#000"/>' +
  '<circle cx="26" cy="18" r="2" fill="#000"/>'
)

// Settings/Gear icon
const SETTINGS_ICON = createSvgIcon('#808080',
  '<circle cx="16" cy="16" r="5" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<rect x="14" y="4" width="4" height="4" fill="#fff"/>' +
  '<rect x="14" y="24" width="4" height="4" fill="#fff"/>' +
  '<rect x="4" y="14" width="4" height="4" fill="#fff"/>' +
  '<rect x="24" y="14" width="4" height="4" fill="#fff"/>'
)

// Mail/Envelope icon
const MAIL_ICON = createSvgIcon('#008080',
  '<rect x="4" y="8" width="24" height="16" fill="#fff" stroke="#000"/>' +
  '<polyline points="4,8 16,18 28,8" fill="none" stroke="#000" stroke-width="1.5"/>'
)

// Terminal/Console icon
const TERMINAL_ICON = createSvgIcon('#000080',
  '<rect x="2" y="2" width="28" height="28" fill="#000" stroke="#c0c0c0" stroke-width="2"/>' +
  '<text x="6" y="16" fill="#0f0" font-family="monospace" font-size="10">C:\\&gt;_</text>'
)

// Calculator icon
const CALCULATOR_ICON = createSvgIcon('#808080',
  '<rect x="6" y="4" width="20" height="24" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="8" y="6" width="16" height="6" fill="#008000"/>' +
  '<rect x="8" y="14" width="4" height="4" fill="#fff" stroke="#000"/>' +
  '<rect x="14" y="14" width="4" height="4" fill="#fff" stroke="#000"/>' +
  '<rect x="20" y="14" width="4" height="4" fill="#fff" stroke="#000"/>' +
  '<rect x="8" y="20" width="4" height="4" fill="#fff" stroke="#000"/>' +
  '<rect x="14" y="20" width="4" height="4" fill="#fff" stroke="#000"/>' +
  '<rect x="20" y="20" width="4" height="4" fill="#fff" stroke="#000"/>'
)

// Image/Picture icon
const IMAGE_ICON = createSvgIcon('#008080',
  '<rect x="4" y="6" width="24" height="20" fill="#fff" stroke="#000"/>' +
  '<circle cx="10" cy="12" r="3" fill="#ff0"/>' +
  '<polygon points="4,26 12,16 20,22 24,18 28,26" fill="#008000"/>'
)

// Code/Developer icon
const CODE_ICON = createSvgIcon('#000080',
  '<polyline points="10,8 4,16 10,24" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<polyline points="22,8 28,16 22,24" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<line x1="18" y1="6" x2="14" y2="26" stroke="#fff" stroke-width="2"/>'
)

// Chat/Message icon
const CHAT_ICON = createSvgIcon('#008080',
  '<path d="M4 6 h24 v14 h-16 l-6 4 v-4 z" fill="#fff" stroke="#000"/>' +
  '<line x1="8" y1="10" x2="24" y2="10" stroke="#808080"/>' +
  '<line x1="8" y1="14" x2="20" y2="14" stroke="#808080"/>'
)

// Database icon
const DATABASE_ICON = createSvgIcon('#800000',
  '<ellipse cx="16" cy="8" rx="10" ry="4" fill="#c0c0c0" stroke="#000"/>' +
  '<path d="M6 8 v16 c0 2.2 4.5 4 10 4 s10-1.8 10-4 v-16" fill="#c0c0c0" stroke="#000"/>' +
  '<ellipse cx="16" cy="16" rx="10" ry="4" fill="none" stroke="#000"/>'
)

// Tool/Wrench icon
const TOOL_ICON = createSvgIcon('#808000',
  '<path d="M22 6 c-2 0-4 2-4 4 c0 1 1 2 1 3 l-10 10 c-1 1-1 2 0 3 l2 2 c1 1 2 1 3 0 l10-10 c1 0 2 1 3 1 c2 0 4-2 4-4 c0-1-1-2-2-2 l-3 3 l-2-2 l3-3 c0-1-1-2-2-2 z" fill="#c0c0c0" stroke="#000"/>'
)

// Download icon
const DOWNLOAD_ICON = createSvgIcon('#008000',
  '<line x1="16" y1="4" x2="16" y2="18" stroke="#fff" stroke-width="3"/>' +
  '<polyline points="10,14 16,20 22,14" fill="none" stroke="#fff" stroke-width="3"/>' +
  '<rect x="6" y="24" width="20" height="4" fill="#fff"/>'
)

// Star/Favorite icon
const STAR_ICON = createSvgIcon('#000080',
  '<polygon points="16,4 19,12 28,13 21,19 23,28 16,24 9,28 11,19 4,13 13,12" fill="#ff0" stroke="#000"/>'
)

// Book/Documentation icon
const BOOK_ICON = createSvgIcon('#800000',
  '<rect x="6" y="4" width="20" height="24" fill="#fff" stroke="#000"/>' +
  '<rect x="6" y="4" width="4" height="24" fill="#800000"/>' +
  '<line x1="12" y1="10" x2="22" y2="10" stroke="#000"/>' +
  '<line x1="12" y1="14" x2="22" y2="14" stroke="#000"/>' +
  '<line x1="12" y1="18" x2="18" y2="18" stroke="#000"/>'
)

// Calendar icon
const CALENDAR_ICON = createSvgIcon('#800080',
  '<rect x="4" y="6" width="24" height="22" fill="#fff" stroke="#000"/>' +
  '<rect x="4" y="6" width="24" height="6" fill="#f00"/>' +
  '<rect x="8" y="3" width="2" height="6" fill="#000"/>' +
  '<rect x="22" y="3" width="2" height="6" fill="#000"/>' +
  '<text x="16" y="23" text-anchor="middle" font-size="10" font-weight="bold">15</text>'
)

// Printer icon
const PRINTER_ICON = createSvgIcon('#808080',
  '<rect x="8" y="4" width="16" height="6" fill="#fff" stroke="#000"/>' +
  '<rect x="4" y="10" width="24" height="10" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="8" y="16" width="16" height="10" fill="#fff" stroke="#000"/>' +
  '<circle cx="24" cy="14" r="2" fill="#0f0"/>'
)

// Search/Magnifier icon
const SEARCH_ICON = createSvgIcon('#008080',
  '<circle cx="13" cy="13" r="7" fill="#fff" stroke="#000" stroke-width="2"/>' +
  '<line x1="18" y1="18" x2="26" y2="26" stroke="#000" stroke-width="3"/>'
)

// Cloud icon
const CLOUD_ICON = createSvgIcon('#008080',
  '<ellipse cx="16" cy="18" rx="12" ry="6" fill="#fff" stroke="#000"/>' +
  '<circle cx="10" cy="14" r="6" fill="#fff" stroke="#000"/>' +
  '<circle cx="20" cy="12" r="7" fill="#fff" stroke="#000"/>'
)

// Lock/Security icon
const LOCK_ICON = createSvgIcon('#808080',
  '<rect x="8" y="14" width="16" height="12" fill="#ff0" stroke="#000" rx="2"/>' +
  '<path d="M10 14 v-4 a6 6 0 0 1 12 0 v4" fill="none" stroke="#000" stroke-width="2"/>' +
  '<circle cx="16" cy="20" r="2" fill="#000"/>'
)

// User/Person icon
const USER_ICON = createSvgIcon('#008080',
  '<circle cx="16" cy="10" r="5" fill="#fff" stroke="#000"/>' +
  '<path d="M6 28 c0-7 5-10 10-10 s10 3 10 10" fill="#fff" stroke="#000"/>'
)

// Open folder icon
const FOLDER_OPEN_ICON = createSvgIcon('#808000',
  '<rect x="4" y="12" width="24" height="12" fill="#c0c000" stroke="#000"/>' +
  '<rect x="6" y="8" width="12" height="6" fill="#c0c000" stroke="#000"/>'
)

// Clock icon
const CLOCK_ICON = createSvgIcon('#008080',
  '<circle cx="16" cy="16" r="10" fill="#fff" stroke="#000"/>' +
  '<line x1="16" y1="16" x2="16" y2="9" stroke="#000" stroke-width="2"/>' +
  '<line x1="16" y1="16" x2="22" y2="16" stroke="#000" stroke-width="2"/>'
)

// Camera icon
const CAMERA_ICON = createSvgIcon('#808080',
  '<rect x="6" y="10" width="20" height="14" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="10" y="8" width="6" height="4" fill="#c0c0c0" stroke="#000"/>' +
  '<circle cx="16" cy="17" r="4" fill="#000" stroke="#fff"/>'
)

// Phone icon
const PHONE_ICON = createSvgIcon('#008080',
  '<rect x="9" y="6" width="14" height="20" rx="2" fill="#fff" stroke="#000"/>' +
  '<rect x="11" y="10" width="10" height="10" fill="#c0c0c0" stroke="#000"/>' +
  '<circle cx="16" cy="23" r="1.5" fill="#000"/>'
)

// Note icon
const NOTE_ICON = createSvgIcon('#808000',
  '<rect x="8" y="6" width="16" height="20" fill="#fff" stroke="#000"/>' +
  '<line x1="10" y1="10" x2="22" y2="10" stroke="#000"/>' +
  '<line x1="10" y1="14" x2="22" y2="14" stroke="#000"/>' +
  '<line x1="10" y1="18" x2="18" y2="18" stroke="#000"/>' +
  '<polygon points="18,6 24,6 24,12" fill="#c0c0c0" stroke="#000"/>'
)

// Speaker icon
const SPEAKER_ICON = createSvgIcon('#800000',
  '<rect x="8" y="10" width="8" height="12" fill="#c0c0c0" stroke="#000"/>' +
  '<polygon points="16,12 22,8 22,24 16,20" fill="#c0c0c0" stroke="#000"/>' +
  '<path d="M24 12 q4 4 0 8" fill="none" stroke="#fff" stroke-width="2"/>'
)

// Trash icon
const TRASH_ICON = createSvgIcon('#808080',
  '<rect x="10" y="10" width="12" height="16" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="8" y="8" width="16" height="3" fill="#c0c0c0" stroke="#000"/>' +
  '<line x1="14" y1="12" x2="14" y2="24" stroke="#000"/>' +
  '<line x1="18" y1="12" x2="18" y2="24" stroke="#000"/>'
)

// Paint icon
const PAINT_ICON = createSvgIcon('#800000',
  '<ellipse cx="14" cy="18" rx="8" ry="6" fill="#c0c0c0" stroke="#000"/>' +
  '<circle cx="10" cy="16" r="1.5" fill="#f00"/>' +
  '<circle cx="14" cy="14" r="1.5" fill="#0f0"/>' +
  '<circle cx="18" cy="16" r="1.5" fill="#00f"/>' +
  '<line x1="20" y1="8" x2="26" y2="14" stroke="#fff" stroke-width="2"/>' +
  '<line x1="19" y1="9" x2="25" y2="15" stroke="#000" stroke-width="1"/>'
)

// Document icon
const DOC_ICON = createSvgIcon('#808080',
  '<rect x="8" y="4" width="16" height="24" fill="#fff" stroke="#000"/>' +
  '<polygon points="18,4 24,4 24,10" fill="#c0c0c0" stroke="#000"/>' +
  '<line x1="10" y1="12" x2="22" y2="12" stroke="#000"/>' +
  '<line x1="10" y1="16" x2="22" y2="16" stroke="#000"/>' +
  '<line x1="10" y1="20" x2="18" y2="20" stroke="#000"/>'
)

// Spreadsheet icon
const SHEET_ICON = createSvgIcon('#008000',
  '<rect x="6" y="6" width="20" height="20" fill="#fff" stroke="#000"/>' +
  '<line x1="12" y1="6" x2="12" y2="26" stroke="#000"/>' +
  '<line x1="18" y1="6" x2="18" y2="26" stroke="#000"/>' +
  '<line x1="6" y1="12" x2="26" y2="12" stroke="#000"/>' +
  '<line x1="6" y1="18" x2="26" y2="18" stroke="#000"/>'
)

// Presentation icon
const SLIDE_ICON = createSvgIcon('#800000',
  '<rect x="4" y="6" width="24" height="14" fill="#fff" stroke="#000"/>' +
  '<line x1="16" y1="20" x2="16" y2="26" stroke="#000"/>' +
  '<line x1="10" y1="26" x2="22" y2="26" stroke="#000"/>' +
  '<rect x="8" y="9" width="10" height="6" fill="#c0c0c0" stroke="#000"/>'
)

// Clipboard icon
const CLIPBOARD_ICON = createSvgIcon('#808080',
  '<rect x="8" y="6" width="16" height="20" fill="#fff" stroke="#000"/>' +
  '<rect x="12" y="4" width="8" height="4" fill="#c0c0c0" stroke="#000"/>' +
  '<line x1="10" y1="12" x2="22" y2="12" stroke="#000"/>' +
  '<line x1="10" y1="16" x2="22" y2="16" stroke="#000"/>' +
  '<line x1="10" y1="20" x2="18" y2="20" stroke="#000"/>'
)

// Archive icon
const ARCHIVE_ICON = createSvgIcon('#808000',
  '<rect x="6" y="10" width="20" height="14" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="6" y="6" width="20" height="6" fill="#808080" stroke="#000"/>' +
  '<rect x="12" y="14" width="8" height="4" fill="#fff" stroke="#000"/>'
)

// Disk icon
const DISK_ICON = createSvgIcon('#808080',
  '<rect x="6" y="6" width="20" height="20" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="9" y="8" width="10" height="6" fill="#fff" stroke="#000"/>' +
  '<rect x="9" y="18" width="14" height="6" fill="#808080" stroke="#000"/>' +
  '<rect x="20" y="8" width="4" height="8" fill="#000"/>'
)

// Drive icon
const DRIVE_ICON = createSvgIcon('#808000',
  '<rect x="6" y="12" width="20" height="10" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="8" y="8" width="20" height="6" fill="#808080" stroke="#000"/>' +
  '<circle cx="22" cy="18" r="1.5" fill="#0f0"/>'
)

// Chip icon
const CHIP_ICON = createSvgIcon('#800000',
  '<rect x="10" y="10" width="12" height="12" fill="#000" stroke="#c0c0c0"/>' +
  '<rect x="12" y="12" width="8" height="8" fill="#c0c0c0" stroke="#000"/>' +
  '<line x1="12" y1="8" x2="12" y2="10" stroke="#c0c0c0"/>' +
  '<line x1="16" y1="8" x2="16" y2="10" stroke="#c0c0c0"/>' +
  '<line x1="20" y1="8" x2="20" y2="10" stroke="#c0c0c0"/>' +
  '<line x1="12" y1="22" x2="12" y2="24" stroke="#c0c0c0"/>' +
  '<line x1="16" y1="22" x2="16" y2="24" stroke="#c0c0c0"/>' +
  '<line x1="20" y1="22" x2="20" y2="24" stroke="#c0c0c0"/>' +
  '<line x1="8" y1="12" x2="10" y2="12" stroke="#c0c0c0"/>' +
  '<line x1="8" y1="16" x2="10" y2="16" stroke="#c0c0c0"/>' +
  '<line x1="8" y1="20" x2="10" y2="20" stroke="#c0c0c0"/>' +
  '<line x1="22" y1="12" x2="24" y2="12" stroke="#c0c0c0"/>' +
  '<line x1="22" y1="16" x2="24" y2="16" stroke="#c0c0c0"/>' +
  '<line x1="22" y1="20" x2="24" y2="20" stroke="#c0c0c0"/>'
)

// Shield icon
const SHIELD_ICON = createSvgIcon('#000080',
  '<path d="M16 6 L24 10 V18 C24 22 20 26 16 28 C12 26 8 22 8 18 V10 Z" fill="#c0c0c0" stroke="#000"/>'
)

// Key icon
const KEY_ICON = createSvgIcon('#808000',
  '<circle cx="12" cy="18" r="4" fill="#ff0" stroke="#000"/>' +
  '<rect x="16" y="17" width="10" height="2" fill="#ff0" stroke="#000"/>' +
  '<rect x="22" y="15" width="2" height="4" fill="#ff0" stroke="#000"/>'
)

// Network icon
const NETWORK_ICON = createSvgIcon('#000080',
  '<circle cx="8" cy="10" r="3" fill="#fff" stroke="#000"/>' +
  '<circle cx="24" cy="10" r="3" fill="#fff" stroke="#000"/>' +
  '<circle cx="16" cy="22" r="3" fill="#fff" stroke="#000"/>' +
  '<line x1="11" y1="11" x2="21" y2="11" stroke="#fff" stroke-width="1.5"/>' +
  '<line x1="10" y1="12" x2="14" y2="20" stroke="#fff" stroke-width="1.5"/>' +
  '<line x1="22" y1="12" x2="18" y2="20" stroke="#fff" stroke-width="1.5"/>'
)

// Bug icon
const BUG_ICON = createSvgIcon('#008080',
  '<circle cx="16" cy="10" r="3" fill="#c0c0c0" stroke="#000"/>' +
  '<ellipse cx="16" cy="18" rx="6" ry="8" fill="#c0c0c0" stroke="#000"/>' +
  '<line x1="10" y1="14" x2="6" y2="12" stroke="#000"/>' +
  '<line x1="10" y1="18" x2="6" y2="20" stroke="#000"/>' +
  '<line x1="22" y1="14" x2="26" y2="12" stroke="#000"/>' +
  '<line x1="22" y1="18" x2="26" y2="20" stroke="#000"/>'
)

// ==========================================
// Additional Icons
// ==========================================

// Globe/World icon (different from web - shows continents)
const GLOBE_ICON = createSvgIcon('#008080',
  '<circle cx="16" cy="16" r="10" fill="#00f" stroke="#000"/>' +
  '<ellipse cx="16" cy="16" rx="4" ry="10" fill="none" stroke="#0f0" stroke-width="1"/>' +
  '<line x1="6" y1="16" x2="26" y2="16" stroke="#0f0" stroke-width="1"/>' +
  '<path d="M8 10 q8 2 16 0" fill="none" stroke="#0f0" stroke-width="1"/>' +
  '<path d="M8 22 q8 -2 16 0" fill="none" stroke="#0f0" stroke-width="1"/>'
)

// Money/Dollar icon
const MONEY_ICON = createSvgIcon('#008000',
  '<circle cx="16" cy="16" r="10" fill="#0f0" stroke="#000"/>' +
  '<text x="16" y="21" text-anchor="middle" font-size="14" font-weight="bold" fill="#000">$</text>'
)

// Heart icon
const HEART_ICON = createSvgIcon('#800000',
  '<path d="M16 26 L8 18 C4 14 4 8 10 8 C13 8 16 11 16 11 C16 11 19 8 22 8 C28 8 28 14 24 18 Z" fill="#f00" stroke="#000"/>'
)

// Lightning/Power icon
const LIGHTNING_ICON = createSvgIcon('#808000',
  '<polygon points="18,4 8,16 14,16 12,28 22,16 16,16" fill="#ff0" stroke="#000"/>'
)

// Coffee/Cup icon
const COFFEE_ICON = createSvgIcon('#800000',
  '<rect x="8" y="10" width="12" height="14" fill="#fff" stroke="#000"/>' +
  '<path d="M20 12 h4 c2 0 3 3 2 6 c-1 2 -2 2 -4 2 h-2" fill="none" stroke="#000" stroke-width="2"/>' +
  '<rect x="6" y="26" width="16" height="2" fill="#808080"/>' +
  '<path d="M10 12 q2 4 0 8" fill="none" stroke="#808080" stroke-width="1"/>'
)

// Home icon
const HOME_ICON = createSvgIcon('#800000',
  '<polygon points="16,4 4,16 8,16 8,26 14,26 14,18 18,18 18,26 24,26 24,16 28,16" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="13" y="18" width="6" height="8" fill="#808080" stroke="#000"/>'
)

// Airplane icon
const AIRPLANE_ICON = createSvgIcon('#000080',
  '<polygon points="16,4 14,12 4,16 14,18 14,24 12,26 16,24 20,26 18,24 18,18 28,16 18,12" fill="#c0c0c0" stroke="#000"/>'
)

// Car icon
const CAR_ICON = createSvgIcon('#800000',
  '<path d="M8 14 L10 10 h12 l2 4" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="6" y="14" width="20" height="8" rx="2" fill="#c0c0c0" stroke="#000"/>' +
  '<circle cx="10" cy="22" r="3" fill="#000"/>' +
  '<circle cx="22" cy="22" r="3" fill="#000"/>' +
  '<rect x="12" y="11" width="3" height="3" fill="#80ffff" stroke="#000"/>' +
  '<rect x="17" y="11" width="3" height="3" fill="#80ffff" stroke="#000"/>'
)

// Rocket icon
const ROCKET_ICON = createSvgIcon('#000080',
  '<ellipse cx="16" cy="14" rx="4" ry="10" fill="#c0c0c0" stroke="#000"/>' +
  '<polygon points="12,22 16,28 20,22" fill="#f00" stroke="#000"/>' +
  '<polygon points="10,18 6,22 12,20" fill="#c0c0c0" stroke="#000"/>' +
  '<polygon points="22,18 26,22 20,20" fill="#c0c0c0" stroke="#000"/>' +
  '<circle cx="16" cy="10" r="2" fill="#80ffff" stroke="#000"/>'
)

// Robot icon
const ROBOT_ICON = createSvgIcon('#808080',
  '<rect x="10" y="8" width="12" height="10" rx="2" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="8" y="18" width="16" height="8" fill="#c0c0c0" stroke="#000"/>' +
  '<circle cx="13" cy="12" r="2" fill="#f00"/>' +
  '<circle cx="19" cy="12" r="2" fill="#f00"/>' +
  '<rect x="14" y="4" width="4" height="4" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="4" y="20" width="4" height="4" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="24" y="20" width="4" height="4" fill="#c0c0c0" stroke="#000"/>'
)

// Puzzle icon
const PUZZLE_ICON = createSvgIcon('#800080',
  '<path d="M6 6 h8 v2 c0 2 4 2 4 0 v-2 h8 v8 h-2 c-2 0-2 4 0 4 h2 v8 h-8 v-2 c0-2-4-2-4 0 v2 h-8 v-8 h2 c2 0 2-4 0-4 h-2 z" fill="#c0c0c0" stroke="#000"/>'
)

// Compass icon
const COMPASS_ICON = createSvgIcon('#008080',
  '<circle cx="16" cy="16" r="10" fill="#fff" stroke="#000" stroke-width="2"/>' +
  '<polygon points="16,6 14,16 16,26 18,16" fill="#f00" stroke="#000"/>' +
  '<polygon points="16,6 18,16 16,26 14,16" fill="#fff" stroke="#000"/>' +
  '<circle cx="16" cy="16" r="2" fill="#000"/>'
)

// Map icon
const MAP_ICON = createSvgIcon('#808000',
  '<polygon points="4,6 12,10 20,6 28,10 28,26 20,22 12,26 4,22" fill="#c0c000" stroke="#000"/>' +
  '<line x1="12" y1="10" x2="12" y2="26" stroke="#000"/>' +
  '<line x1="20" y1="6" x2="20" y2="22" stroke="#000"/>' +
  '<circle cx="16" cy="14" r="2" fill="#f00"/>'
)

// Headphones icon
const HEADPHONES_ICON = createSvgIcon('#800080',
  '<path d="M8 18 v-4 a8 8 0 0 1 16 0 v4" fill="none" stroke="#c0c0c0" stroke-width="3"/>' +
  '<rect x="4" y="16" width="6" height="10" rx="2" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="22" y="16" width="6" height="10" rx="2" fill="#c0c0c0" stroke="#000"/>'
)

// Microphone icon
const MICROPHONE_ICON = createSvgIcon('#808080',
  '<rect x="12" y="6" width="8" height="12" rx="4" fill="#c0c0c0" stroke="#000"/>' +
  '<path d="M8 14 v2 a8 8 0 0 0 16 0 v-2" fill="none" stroke="#000" stroke-width="2"/>' +
  '<line x1="16" y1="24" x2="16" y2="28" stroke="#000" stroke-width="2"/>' +
  '<line x1="12" y1="28" x2="20" y2="28" stroke="#000" stroke-width="2"/>'
)

// Battery icon
const BATTERY_ICON = createSvgIcon('#008000',
  '<rect x="4" y="10" width="22" height="12" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="26" y="14" width="2" height="4" fill="#000"/>' +
  '<rect x="6" y="12" width="14" height="8" fill="#0f0"/>'
)

// Wifi icon
const WIFI_ICON = createSvgIcon('#000080',
  '<path d="M4 12 q12 -8 24 0" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<path d="M8 16 q8 -6 16 0" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<path d="M12 20 q4 -4 8 0" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<circle cx="16" cy="24" r="2" fill="#fff"/>'
)

// Bluetooth icon
const BLUETOOTH_ICON = createSvgIcon('#000080',
  '<path d="M16 4 L22 10 L16 16 L22 22 L16 28 L16 16 L10 22 M16 16 L10 10" fill="none" stroke="#fff" stroke-width="2"/>'
)

// Gear/Cog icon (alternative to settings)
const GEAR_ICON = createSvgIcon('#808080',
  '<circle cx="16" cy="16" r="5" fill="#c0c0c0" stroke="#000"/>' +
  '<path d="M16 4 v4 M16 24 v4 M4 16 h4 M24 16 h4 M7 7 l3 3 M22 22 l3 3 M7 25 l3-3 M22 10 l3-3" stroke="#c0c0c0" stroke-width="3"/>'
)

// Lightbulb icon
const LIGHTBULB_ICON = createSvgIcon('#808000',
  '<circle cx="16" cy="12" r="7" fill="#ff0" stroke="#000"/>' +
  '<rect x="12" y="19" width="8" height="4" fill="#c0c0c0" stroke="#000"/>' +
  '<rect x="13" y="23" width="6" height="2" fill="#c0c0c0" stroke="#000"/>' +
  '<line x1="14" y1="21" x2="18" y2="21" stroke="#000"/>'
)

// Bell/Notification icon
const BELL_ICON = createSvgIcon('#808000',
  '<path d="M16 4 v2 M10 10 a6 6 0 0 1 12 0 v8 l2 2 v2 h-16 v-2 l2-2 v-8" fill="#ff0" stroke="#000"/>' +
  '<circle cx="16" cy="26" r="2" fill="#ff0" stroke="#000"/>'
)

// Flag icon
const FLAG_ICON = createSvgIcon('#800000',
  '<rect x="8" y="4" width="2" height="24" fill="#808080"/>' +
  '<polygon points="10,4 26,10 10,16" fill="#f00" stroke="#000"/>'
)

// Pin/Thumbtack icon
const PIN_ICON = createSvgIcon('#800000',
  '<circle cx="16" cy="10" r="6" fill="#f00" stroke="#000"/>' +
  '<polygon points="14,16 18,16 16,28" fill="#808080" stroke="#000"/>'
)

// Eye icon
const EYE_ICON = createSvgIcon('#008080',
  '<ellipse cx="16" cy="16" rx="12" ry="7" fill="#fff" stroke="#000"/>' +
  '<circle cx="16" cy="16" r="5" fill="#008080" stroke="#000"/>' +
  '<circle cx="16" cy="16" r="2" fill="#000"/>'
)

// Hand/Touch icon
const HAND_ICON = createSvgIcon('#808000',
  '<path d="M12 14 v-6 a2 2 0 0 1 4 0 v6 M16 10 v-4 a2 2 0 0 1 4 0 v6 M20 12 v-2 a2 2 0 0 1 4 0 v8 c0 6 -4 10 -10 10 h-2 c-4 0 -6 -2 -6 -6 v-4 a2 2 0 0 1 4 0" fill="#c0c000" stroke="#000"/>'
)

// Pencil/Edit icon
const PENCIL_ICON = createSvgIcon('#808000',
  '<polygon points="6,26 4,28 8,28 24,12 20,8" fill="#ff0" stroke="#000"/>' +
  '<polygon points="20,8 24,12 28,8 24,4" fill="#c0c0c0" stroke="#000"/>' +
  '<line x1="20" y1="8" x2="24" y2="12" stroke="#000"/>'
)

// Clipboard with checkmark icon
const CLIPBOARD_CHECK_ICON = createSvgIcon('#008000',
  '<rect x="8" y="6" width="16" height="20" fill="#fff" stroke="#000"/>' +
  '<rect x="12" y="4" width="8" height="4" fill="#c0c0c0" stroke="#000"/>' +
  '<polyline points="11,16 14,19 21,12" fill="none" stroke="#008000" stroke-width="2"/>'
)

// Folder with star icon
const FOLDER_STAR_ICON = createSvgIcon('#808000',
  '<rect x="4" y="10" width="24" height="14" fill="#c0c000" stroke="#000"/>' +
  '<rect x="6" y="6" width="10" height="6" fill="#c0c000" stroke="#000"/>' +
  '<polygon points="16,12 17.5,15 21,15.5 18.5,18 19,21.5 16,20 13,21.5 13.5,18 11,15.5 14.5,15" fill="#ff0" stroke="#000"/>'
)

// Bookmark icon
const BOOKMARK_ICON = createSvgIcon('#800000',
  '<path d="M10 4 h12 v24 l-6-4 l-6 4 z" fill="#f00" stroke="#000"/>'
)

// Tag icon
const TAG_ICON = createSvgIcon('#008080',
  '<path d="M4 4 h12 l10 10 l-10 10 l-12 -12 z" fill="#c0c0c0" stroke="#000"/>' +
  '<circle cx="10" cy="10" r="2" fill="#000"/>'
)

// Upload icon
const UPLOAD_ICON = createSvgIcon('#008000',
  '<line x1="16" y1="20" x2="16" y2="6" stroke="#fff" stroke-width="3"/>' +
  '<polyline points="10,10 16,4 22,10" fill="none" stroke="#fff" stroke-width="3"/>' +
  '<rect x="6" y="24" width="20" height="4" fill="#fff"/>'
)

// Link/Chain icon
const LINK_ICON = createSvgIcon('#000080',
  '<path d="M10 16 h-2 a4 4 0 0 1 0-8 h6" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<path d="M22 16 h2 a4 4 0 0 0 0-8 h-6" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<line x1="12" y1="16" x2="20" y2="8" stroke="#fff" stroke-width="2"/>'
)

// Power/On-Off icon
const POWER_ICON = createSvgIcon('#800000',
  '<circle cx="16" cy="16" r="10" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<line x1="16" y1="6" x2="16" y2="16" stroke="#fff" stroke-width="3"/>'
)

// Refresh/Sync icon
const REFRESH_ICON = createSvgIcon('#008080',
  '<path d="M6 16 a10 10 0 0 1 17-7" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<path d="M26 16 a10 10 0 0 1 -17 7" fill="none" stroke="#fff" stroke-width="2"/>' +
  '<polygon points="23,6 26,12 20,12" fill="#fff"/>' +
  '<polygon points="9,26 6,20 12,20" fill="#fff"/>'
)

// Sun/Brightness icon
const SUN_ICON = createSvgIcon('#808000',
  '<circle cx="16" cy="16" r="6" fill="#ff0" stroke="#000"/>' +
  '<line x1="16" y1="4" x2="16" y2="8" stroke="#ff0" stroke-width="2"/>' +
  '<line x1="16" y1="24" x2="16" y2="28" stroke="#ff0" stroke-width="2"/>' +
  '<line x1="4" y1="16" x2="8" y2="16" stroke="#ff0" stroke-width="2"/>' +
  '<line x1="24" y1="16" x2="28" y2="16" stroke="#ff0" stroke-width="2"/>' +
  '<line x1="7" y1="7" x2="10" y2="10" stroke="#ff0" stroke-width="2"/>' +
  '<line x1="22" y1="22" x2="25" y2="25" stroke="#ff0" stroke-width="2"/>' +
  '<line x1="7" y1="25" x2="10" y2="22" stroke="#ff0" stroke-width="2"/>' +
  '<line x1="22" y1="10" x2="25" y2="7" stroke="#ff0" stroke-width="2"/>'
)

// Moon/Night icon
const MOON_ICON = createSvgIcon('#000080',
  '<path d="M20 6 a10 10 0 1 0 0 20 a8 8 0 0 1 0-20" fill="#ff0" stroke="#000"/>'
)

// Builtin icons collection for the icon picker
export interface IconOption {
  id: string
  name: string
  icon: string
}

export const BUILTIN_ICONS: IconOption[] = [
  { id: 'default', name: 'Default', icon: DEFAULT_ITEM_ICON },
  { id: 'folder', name: 'Folder', icon: DEFAULT_FOLDER_ICON },
  { id: 'web', name: 'Web', icon: WEB_ICON },
  { id: 'music', name: 'Music', icon: MUSIC_ICON },
  { id: 'video', name: 'Video', icon: VIDEO_ICON },
  { id: 'game', name: 'Game', icon: GAME_ICON },
  { id: 'settings', name: 'Settings', icon: SETTINGS_ICON },
  { id: 'mail', name: 'Mail', icon: MAIL_ICON },
  { id: 'terminal', name: 'Terminal', icon: TERMINAL_ICON },
  { id: 'calculator', name: 'Calculator', icon: CALCULATOR_ICON },
  { id: 'image', name: 'Image', icon: IMAGE_ICON },
  { id: 'code', name: 'Code', icon: CODE_ICON },
  { id: 'chat', name: 'Chat', icon: CHAT_ICON },
  { id: 'database', name: 'Database', icon: DATABASE_ICON },
  { id: 'tool', name: 'Tool', icon: TOOL_ICON },
  { id: 'download', name: 'Download', icon: DOWNLOAD_ICON },
  { id: 'star', name: 'Favorite', icon: STAR_ICON },
  { id: 'book', name: 'Book', icon: BOOK_ICON },
  { id: 'calendar', name: 'Calendar', icon: CALENDAR_ICON },
  { id: 'printer', name: 'Printer', icon: PRINTER_ICON },
  { id: 'search', name: 'Search', icon: SEARCH_ICON },
  { id: 'cloud', name: 'Cloud', icon: CLOUD_ICON },
  { id: 'lock', name: 'Security', icon: LOCK_ICON },
  { id: 'user', name: 'User', icon: USER_ICON },
  { id: 'folder-open', name: 'Open Folder', icon: FOLDER_OPEN_ICON },
  { id: 'clock', name: 'Clock', icon: CLOCK_ICON },
  { id: 'camera', name: 'Camera', icon: CAMERA_ICON },
  { id: 'phone', name: 'Phone', icon: PHONE_ICON },
  { id: 'note', name: 'Note', icon: NOTE_ICON },
  { id: 'speaker', name: 'Speaker', icon: SPEAKER_ICON },
  { id: 'trash', name: 'Trash', icon: TRASH_ICON },
  { id: 'paint', name: 'Paint', icon: PAINT_ICON },
  { id: 'document', name: 'Document', icon: DOC_ICON },
  { id: 'spreadsheet', name: 'Spreadsheet', icon: SHEET_ICON },
  { id: 'presentation', name: 'Presentation', icon: SLIDE_ICON },
  { id: 'clipboard', name: 'Clipboard', icon: CLIPBOARD_ICON },
  { id: 'archive', name: 'Archive', icon: ARCHIVE_ICON },
  { id: 'disk', name: 'Disk', icon: DISK_ICON },
  { id: 'drive', name: 'Drive', icon: DRIVE_ICON },
  { id: 'chip', name: 'Chip', icon: CHIP_ICON },
  { id: 'shield', name: 'Shield', icon: SHIELD_ICON },
  { id: 'key', name: 'Key', icon: KEY_ICON },
  { id: 'network', name: 'Network', icon: NETWORK_ICON },
  { id: 'bug', name: 'Bug', icon: BUG_ICON },
  // Additional icons
  { id: 'globe', name: 'Globe', icon: GLOBE_ICON },
  { id: 'money', name: 'Money', icon: MONEY_ICON },
  { id: 'heart', name: 'Heart', icon: HEART_ICON },
  { id: 'lightning', name: 'Lightning', icon: LIGHTNING_ICON },
  { id: 'coffee', name: 'Coffee', icon: COFFEE_ICON },
  { id: 'home', name: 'Home', icon: HOME_ICON },
  { id: 'airplane', name: 'Airplane', icon: AIRPLANE_ICON },
  { id: 'car', name: 'Car', icon: CAR_ICON },
  { id: 'rocket', name: 'Rocket', icon: ROCKET_ICON },
  { id: 'robot', name: 'Robot', icon: ROBOT_ICON },
  { id: 'puzzle', name: 'Puzzle', icon: PUZZLE_ICON },
  { id: 'compass', name: 'Compass', icon: COMPASS_ICON },
  { id: 'map', name: 'Map', icon: MAP_ICON },
  { id: 'headphones', name: 'Headphones', icon: HEADPHONES_ICON },
  { id: 'microphone', name: 'Microphone', icon: MICROPHONE_ICON },
  { id: 'battery', name: 'Battery', icon: BATTERY_ICON },
  { id: 'wifi', name: 'Wifi', icon: WIFI_ICON },
  { id: 'bluetooth', name: 'Bluetooth', icon: BLUETOOTH_ICON },
  { id: 'gear', name: 'Gear', icon: GEAR_ICON },
  { id: 'lightbulb', name: 'Lightbulb', icon: LIGHTBULB_ICON },
  { id: 'bell', name: 'Bell', icon: BELL_ICON },
  { id: 'flag', name: 'Flag', icon: FLAG_ICON },
  { id: 'pin', name: 'Pin', icon: PIN_ICON },
  { id: 'eye', name: 'Eye', icon: EYE_ICON },
  { id: 'hand', name: 'Hand', icon: HAND_ICON },
  { id: 'pencil', name: 'Pencil', icon: PENCIL_ICON },
  { id: 'clipboard-check', name: 'Clipboard Check', icon: CLIPBOARD_CHECK_ICON },
  { id: 'folder-star', name: 'Favorite Folder', icon: FOLDER_STAR_ICON },
  { id: 'bookmark', name: 'Bookmark', icon: BOOKMARK_ICON },
  { id: 'tag', name: 'Tag', icon: TAG_ICON },
  { id: 'upload', name: 'Upload', icon: UPLOAD_ICON },
  { id: 'link', name: 'Link', icon: LINK_ICON },
  { id: 'power', name: 'Power', icon: POWER_ICON },
  { id: 'refresh', name: 'Refresh', icon: REFRESH_ICON },
  { id: 'sun', name: 'Sun', icon: SUN_ICON },
  { id: 'moon', name: 'Moon', icon: MOON_ICON }
]

// Helper to get icon source - handles both data URLs and icon IDs
export function getIconSrc(icon: string | undefined): string {
  if (!icon) {
    return DEFAULT_ITEM_ICON
  }

  // Check if it's a builtin icon ID
  const builtinIcon = BUILTIN_ICONS.find((i) => i.id === icon)
  if (builtinIcon) {
    return builtinIcon.icon
  }

  // Legacy support for old icon names
  if (icon === 'default-item.png') {
    return DEFAULT_ITEM_ICON
  }
  if (icon === 'folder.png') {
    return DEFAULT_FOLDER_ICON
  }
  if (icon === 'question.png') {
    return QUESTION_ICON
  }
  if (icon === 'program-manager.png') {
    return APP_ICON
  }

  // If it's already a data URL or web URL, return as-is
  if (icon.startsWith('data:') || icon.startsWith('http')) {
    return icon
  }

  // File URLs or absolute paths (including Windows)
  if (icon.startsWith('file://')) {
    return icon
  }

  const normalizedPath = icon.replace(/\\/g, '/')
  if (/^[a-zA-Z]:\//.test(normalizedPath)) {
    return `file:///${normalizedPath}`
  }
  if (normalizedPath.startsWith('//')) {
    return `file:${normalizedPath}`
  }
  if (icon.startsWith('/')) {
    return icon
  }

  // Default fallback
  return DEFAULT_ITEM_ICON
}
