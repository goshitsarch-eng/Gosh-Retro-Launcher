#!/usr/bin/env node
/* Non-stop variant of run-win95-visuals.cjs: runs every scenario, reports pass/fail summary. */
const { spawnSync } = require('node:child_process')
const path = require('node:path')
const electron = require('electron')

const root = path.join(__dirname, '..')
const scenarios = [
  'win95-desktop', 'win95-selected', 'win95-desktop-inactive', 'win95-desktop-marquee',
  'win95-keyboard-start', 'win95-start', 'win95-programs', 'win95-program-items',
  'win95-settings', 'win95-taskbar-context', 'win95-task-context', 'win95-my-computer',
  'win95-group', 'win95-folder-small', 'win95-folder-list', 'win95-folder-details',
  'win95-folder-multiselect', 'win95-folder-context', 'win95-window-inactive',
  'win95-window-maximized', 'win95-window-minimized', 'win95-menubar', 'win95-system-menu',
  'win95-move-outline', 'win95-size-outline', 'win95-find', 'win95-find-results',
  'win95-find-date', 'win95-find-advanced', 'win95-run', 'win95-shutdown', 'win95-wizard',
  'win95-properties', 'win95-message', 'win95-scale2', 'win95-scale3', 'win95-scale4',
  'win95-remainder', 'win95-dpi125'
]

const failures = []
for (const name of scenarios) {
  const artifact = path.join(root, 'artifacts', `${name}.png`)
  const baseline = path.join(root, 'tests', 'visual', 'baselines', `${name}.png`)
  const args = [path.join(root, 'scripts', 'capture-wfw.cjs'), artifact, name, baseline]
  const result = spawnSync(electron, args, { cwd: root, stdio: 'pipe' })
  const out = `${result.stdout || ''}${result.stderr || ''}`
  const diff = (out.match(/visual difference: ([\d.]+)%/) || [])[1]
  if (result.status === 0) {
    console.log(`PASS ${name} (${diff ?? '?'}%)`)
  } else {
    failures.push(name)
    console.log(`FAIL ${name} (${diff ?? 'no-diff'}%)`)
  }
}
console.log(`\n${scenarios.length - failures.length}/${scenarios.length} passed; failures: ${failures.join(', ') || 'none'}`)
process.exit(failures.length ? 1 : 0)
