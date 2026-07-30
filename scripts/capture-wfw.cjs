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
const isWin95View = view === 'win95' || view.startsWith('win95-')
const fixtureScale = view === 'scale2' ? 2
  : ['win95-scale2', 'win95-remainder', 'win95-dpi125'].includes(view) ? 2
    : view === 'win95-scale3' ? 3 : view === 'win95-scale4' ? 4 : 1
const fixtureIconY = view === 'reference' ? 219 : 367
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'gosh-wfw-capture-'))
app.setPath('userData', profile)
if (view === 'win95-dpi125') app.commandLine.appendSwitch('force-device-scale-factor', '1.25')

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
    shell: isWin95View ? 'win95' : 'win31', win31Scale: fixtureScale, win95Scale: fixtureScale, trayOnClose: false, soundEnabled: false,
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
  if (isWin95View) {
    if (view === 'win95-remainder') win.setContentSize(1281, 961)
    else win.setContentSize(640 * fixtureScale, 480 * fixtureScale)
  }
  await new Promise((resolve) => setTimeout(resolve, 800))
  if (isWin95View) {
    win.webContents.sendInputEvent({ type: 'mouseMove', x: Math.max(10, 620 * fixtureScale), y: 10 })
    await win.webContents.executeJavaScript(`window.dispatchEvent(new CustomEvent('win95-capture-clock', { detail: '12:00 PM' }))`)
    await new Promise((resolve) => setTimeout(resolve, 40))
    if (view === 'win95-selected') {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-desktop-icon')?.click()`)
    }
    if (view === 'win95-keyboard-start') {
      await win.webContents.executeJavaScript(`window.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', ctrlKey: true, bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 60))
      await win.webContents.executeJavaScript(`window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 60))
    }
    if (['win95-start', 'win95-programs', 'win95-program-items', 'win95-run', 'win95-find', 'win95-shutdown'].includes(view)) {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-start-button')?.click()`)
      await new Promise((resolve) => setTimeout(resolve, 60))
    }
    if (view === 'win95-programs' || view === 'win95-program-items') {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-start-command')?.dispatchEvent(new PointerEvent('pointerover', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 300))
    }
    if (view === 'win95-program-items') {
      await win.webContents.executeJavaScript(`document.querySelector('.start-level-1 .win95-sub-command')?.dispatchEvent(new PointerEvent('pointerover', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 300))
    }
    if (view === 'win95-run') {
      await win.webContents.executeJavaScript(`
        [...document.querySelectorAll('.win95-start-command')].find((element) => element.textContent?.includes('Run...'))?.click()
      `)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (view === 'win95-find') {
      await win.webContents.executeJavaScript(`
        [...document.querySelectorAll('.win95-start-command')].find((element) => element.textContent?.includes('Find'))?.click()
      `)
      await new Promise((resolve) => setTimeout(resolve, 60))
      await win.webContents.executeJavaScript(`document.querySelector('.start-level-1 .win95-sub-command')?.click()`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (view === 'win95-shutdown') {
      await win.webContents.executeJavaScript(`
        [...document.querySelectorAll('.win95-start-command')].find((element) => element.textContent?.includes('Shut Down'))?.click()
      `)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (view === 'win95-my-computer' || view === 'win95-group') {
      await win.webContents.executeJavaScript(`document.querySelector('[data-desktop-icon="my-computer"]')?.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (view === 'win95-group') {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-folder-item')?.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }

    const openMyComputer = async () => {
      await win.webContents.executeJavaScript(`document.querySelector('[data-desktop-icon="my-computer"]')?.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 120))
    }
    const openMainGroup = async () => {
      await openMyComputer()
      await win.webContents.executeJavaScript(`document.querySelector('.win95-folder-item')?.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 120))
    }
    const chooseView = async (label) => {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-window.active [data-menu="view"]')?.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 60))
      await win.webContents.executeJavaScript(`
        [...document.querySelectorAll('.win95-popup-item')].find((element) => element.textContent?.includes(${JSON.stringify(label)}))?.click()
      `)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    const openFind = async () => {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-start-button')?.click()`)
      await new Promise((resolve) => setTimeout(resolve, 60))
      await win.webContents.executeJavaScript(`
        [...document.querySelectorAll('.win95-start-command')].find((element) => element.textContent?.includes('Find'))?.click()
      `)
      await new Promise((resolve) => setTimeout(resolve, 80))
      await win.webContents.executeJavaScript(`document.querySelector('.start-level-1 .win95-sub-command')?.click()`)
      await new Promise((resolve) => setTimeout(resolve, 150))
    }

    if (view === 'win95-desktop-inactive') {
      await win.webContents.executeJavaScript(`document.querySelector('[data-desktop-icon="my-computer"]')?.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, button: 0 }))`)
      await openMyComputer()
    }
    if (view === 'win95-desktop-marquee') {
      await win.webContents.executeJavaScript(`
        const desktop = document.querySelector('.win95-desktop');
        desktop?.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, button: 0, clientX: 1, clientY: 1 }));
        document.dispatchEvent(new PointerEvent('pointermove', { bubbles: true, buttons: 1, clientX: 82, clientY: 226 }));
      `)
      await new Promise((resolve) => setTimeout(resolve, 80))
    }
    if (view === 'win95-settings') {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-start-button')?.click()`)
      await new Promise((resolve) => setTimeout(resolve, 60))
      await win.webContents.executeJavaScript(`
        [...document.querySelectorAll('.win95-start-command')].find((element) => element.textContent?.includes('Settings'))?.dispatchEvent(new PointerEvent('pointerover', { bubbles: true }))
      `)
      await new Promise((resolve) => setTimeout(resolve, 300))
    }
    if (view === 'win95-taskbar-context') {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-taskbar')?.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, clientX: 300, clientY: 470 }))`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (view === 'win95-task-context') {
      await openMyComputer()
      await win.webContents.executeJavaScript(`document.querySelector('[data-task-window]')?.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, clientX: 100, clientY: 470 }))`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (['win95-folder-small', 'win95-folder-list', 'win95-folder-details', 'win95-folder-multiselect'].includes(view)) {
      await openMainGroup()
      if (view === 'win95-folder-small') await chooseView('Small Icons')
      if (view === 'win95-folder-list') await chooseView('List')
      if (view === 'win95-folder-details') await chooseView('Details')
      if (view === 'win95-folder-multiselect') {
        await win.webContents.executeJavaScript(`
          const items = document.querySelectorAll('.win95-window.active .win95-folder-item');
          items[0]?.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, button: 0 }));
          items[2]?.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, button: 0, ctrlKey: true }));
          items[4]?.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true, button: 0, shiftKey: true }));
        `)
        await new Promise((resolve) => setTimeout(resolve, 80))
      }
    }
    if (view === 'win95-window-inactive') {
      await openMyComputer()
      await win.webContents.executeJavaScript(`document.querySelector('.win95-folder-item')?.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 120))
    }
    if (view === 'win95-window-maximized') {
      await openMyComputer()
      await win.webContents.executeJavaScript(`document.querySelector('.win95-window.active [aria-label="Maximize"]')?.click()`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (view === 'win95-window-minimized') {
      await openMyComputer()
      await win.webContents.executeJavaScript(`document.querySelector('.win95-window.active [aria-label="Minimize"]')?.click()`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (view === 'win95-menubar') {
      await openMyComputer()
      await win.webContents.executeJavaScript(`document.querySelector('.win95-window.active [data-menu="file"]')?.dispatchEvent(new PointerEvent('pointerdown', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (view === 'win95-system-menu' || view === 'win95-move-outline' || view === 'win95-size-outline') {
      await openMyComputer()
      await win.webContents.executeJavaScript(`document.querySelector('.win95-window.active .win95-caption-icon')?.click()`)
      await new Promise((resolve) => setTimeout(resolve, 80))
      if (view === 'win95-move-outline' || view === 'win95-size-outline') {
        const command = view === 'win95-move-outline' ? 'Move' : 'Size'
        await win.webContents.executeJavaScript(`
          [...document.querySelectorAll('.win95-popup-item')].find((element) => element.textContent?.includes(${JSON.stringify(command)}))?.click();
          window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', shiftKey: true, bubbles: true }));
          window.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', shiftKey: true, bubbles: true }));
        `)
        await new Promise((resolve) => setTimeout(resolve, 100))
      }
    }
    if (view === 'win95-folder-context') {
      await openMainGroup()
      await win.webContents.executeJavaScript(`document.querySelector('.win95-window.active .win95-folder-item')?.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, clientX: 80, clientY: 100 }))`)
      await new Promise((resolve) => setTimeout(resolve, 100))
    }
    if (['win95-find-results', 'win95-find-date', 'win95-find-advanced'].includes(view)) {
      await openFind()
      if (view === 'win95-find-results') {
        await win.webContents.executeJavaScript(`
          [...document.querySelectorAll('.win95-find-actions button')].find((element) => element.textContent?.includes('Find Now'))?.click()
        `)
        await new Promise((resolve) => setTimeout(resolve, 350))
      } else {
        const label = view === 'win95-find-date' ? 'Date Modified' : 'Advanced'
        await win.webContents.executeJavaScript(`
          [...document.querySelectorAll('.win95-find-tabs button')].find((element) => element.textContent?.includes(${JSON.stringify(label)}))?.click()
        `)
        await new Promise((resolve) => setTimeout(resolve, 100))
      }
    }
    if (view === 'win95-wizard') {
      await win.webContents.executeJavaScript(`document.querySelector('.win95-desktop')?.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, clientX: 300, clientY: 250 }))`)
      await new Promise((resolve) => setTimeout(resolve, 80))
      await win.webContents.executeJavaScript(`
        [...document.querySelectorAll('.win95-popup-item')].find((element) => element.textContent?.includes('New Shortcut'))?.click()
      `)
      await new Promise((resolve) => setTimeout(resolve, 120))
    }
    if (view === 'win95-properties') {
      await openMyComputer()
      await win.webContents.executeJavaScript(`document.querySelector('.win95-window.active .win95-folder-item')?.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, clientX: 80, clientY: 100 }))`)
      await new Promise((resolve) => setTimeout(resolve, 80))
      await win.webContents.executeJavaScript(`
        [...document.querySelectorAll('.win95-popup-item')].find((element) => element.textContent?.includes('Properties'))?.click()
      `)
      await new Promise((resolve) => setTimeout(resolve, 120))
    }
    if (view === 'win95-message') {
      await win.webContents.executeJavaScript(`document.querySelector('[data-desktop-icon="network-neighborhood"]')?.dispatchEvent(new MouseEvent('dblclick', { bubbles: true }))`)
      await new Promise((resolve) => setTimeout(resolve, 120))
    }
  }
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
    if (ratio > 0.005) throw new Error(`${isWin95View ? 'Win95' : 'WfW'} visual regression exceeded the 0.5% threshold`)
  }
  app.exit(0)
}

app.whenReady().then(() => void capture().catch((error) => {
  console.error(error)
  app.exit(1)
}))
