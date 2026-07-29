/* Deterministic local WfW visual smoke capture.
 * Usage: npm run build && electron scripts/capture-wfw.cjs [output.png]
 */
const { app, BrowserWindow, nativeImage } = require('electron')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')

const output = path.resolve(process.argv[2] || 'wfw-smoke.png')
const view = process.argv[3] || 'workspace'
const baseline = process.argv[4] ? path.resolve(process.argv[4]) : null
const fixtureScale = view === 'scale2' ? 2 : 1
const fixtureIconY = view === 'reference' ? 219 : 367
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'gosh-wfw-capture-'))
app.setPath('userData', profile)

const windowState = (x, y, width, height, minimized = false) => ({
  x, y, width, height, minimized, maximized: false
})
const item = (id, name, icon, index) => ({
  id,
  name,
  path: '',
  icon,
  workingDir: '',
  win31Position: { x: (index % 5) * 75 + 4, y: Math.floor(index / 5) * 72 + 5 }
})
const mainItems = [
  ['File Manager', 'file-manager'],
  ['Control Panel', 'control-panel'],
  ['Print Manager', 'print-manager'],
  ['ClipBook Viewer', 'clipbook'],
  ['MS-DOS Prompt', 'dos'],
  ['Windows Setup', 'setup'],
  ['PIF Editor', 'pif'],
  ['Read Me', 'readme']
].map(([name, icon], index) => item(`main-${index}`, name, icon, index))
const groups = [
  {
    id: 'main', name: 'Main', icon: 'group',
    windowState: windowState(0, 0, 416, 201),
    shellWindowState: { win31: windowState(0, 0, 416, 201), win95: windowState(20, 20, 416, 201) },
    win31IconPosition: { x: 300, y: fixtureIconY }, items: mainItems
  },
  ...['Accessories', 'Network', 'Games', 'StartUp'].map((name, index) => ({
    id: name.toLowerCase(), name, icon: 'group',
    windowState: windowState(20, 20, 300, 200, true),
    shellWindowState: { win31: windowState(20, 20, 300, 200, true), win95: windowState(20, 20, 300, 200, true) },
    win31IconPosition: { x: index * 75, y: fixtureIconY }, items: []
  }))
]
fs.writeFileSync(path.join(profile, 'program-manager-data.json'), JSON.stringify({
  schemaVersion: 2,
  groups,
  settings: {
    shell: view === 'win95' ? 'win95' : 'win31', win31Scale: fixtureScale, trayOnClose: false, soundEnabled: false,
    win31DesktopMode: view === 'desktop' || view === 'desktop-minimized',
    win31ProgramManagerMinimized: view === 'desktop-minimized'
  }
}, null, 2))

require('../out/main/index.js')

async function capture() {
  let win
  for (let index = 0; index < 100; index += 1) {
    win = BrowserWindow.getAllWindows()[0]
    if (win && !win.webContents.isLoading()) break
    await new Promise((resolve) => setTimeout(resolve, 50))
  }
  if (!win) throw new Error('Program Manager window was not created')
  if (view === 'tools') {
    await win.webContents.executeJavaScript('window.electronAPI.app.openLauncherTools()')
    for (let index = 0; index < 100; index += 1) {
      const candidate = BrowserWindow.getAllWindows().find((window) => window !== win)
      if (candidate && !candidate.webContents.isLoading()) { win = candidate; break }
      await new Promise((resolve) => setTimeout(resolve, 50))
    }
  }
  if (view === 'reference') win.setBounds({ width: 511, height: 335 })
  await new Promise((resolve) => setTimeout(resolve, 800))
  if (view === 'file' || view === 'about') {
    await win.webContents.executeJavaScript(`
      document.querySelectorAll('.wfw-menu-button')[${view === 'about' ? 3 : 0}]
        ?.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }));
    `)
    await new Promise((resolve) => setTimeout(resolve, 80))
  }
  if (view === 'about') {
    await win.webContents.executeJavaScript(`
      [...document.querySelectorAll('.wfw-popup-item')]
        .find((element) => element.textContent?.includes('About Program Manager'))?.click();
    `)
    await new Promise((resolve) => setTimeout(resolve, 500))
  }
  const image = await win.capturePage()
  fs.mkdirSync(path.dirname(output), { recursive: true })
  fs.writeFileSync(output, image.toPNG())
  console.log(output)
  if (baseline) {
    const expected = nativeImage.createFromPath(baseline)
    const actualSize = image.getSize()
    const expectedSize = expected.getSize()
    if (expected.isEmpty() || actualSize.width !== expectedSize.width || actualSize.height !== expectedSize.height) {
      throw new Error(`Visual baseline size mismatch: expected ${expectedSize.width}x${expectedSize.height}, received ${actualSize.width}x${actualSize.height}`)
    }
    const actual = image.toBitmap()
    const reference = expected.toBitmap()
    let changedPixels = 0
    for (let offset = 0; offset < actual.length; offset += 4) {
      if (Math.abs(actual[offset] - reference[offset]) > 20 ||
          Math.abs(actual[offset + 1] - reference[offset + 1]) > 20 ||
          Math.abs(actual[offset + 2] - reference[offset + 2]) > 20) changedPixels += 1
    }
    const ratio = changedPixels / (actualSize.width * actualSize.height)
    console.log(`visual difference: ${(ratio * 100).toFixed(3)}%`)
    if (ratio > 0.005) throw new Error('WfW visual regression exceeded the 0.5% threshold')
  }
  app.exit(0)
}

app.whenReady().then(() => void capture().catch((error) => {
  console.error(error)
  app.exit(1)
}))
