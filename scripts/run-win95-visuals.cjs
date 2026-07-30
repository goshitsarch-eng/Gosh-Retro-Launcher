#!/usr/bin/env node
const { spawnSync } = require('node:child_process')
const fs = require('node:fs')
const path = require('node:path')
const electron = require('electron')

const update = process.argv.includes('--update')
const root = path.join(__dirname, '..')
const scenarios = [
  ['win95', 'win95-desktop'],
  ['win95-selected', 'win95-selected'],
  ['win95-desktop-inactive', 'win95-desktop-inactive'],
  ['win95-desktop-marquee', 'win95-desktop-marquee'],
  ['win95-keyboard-start', 'win95-keyboard-start'],
  ['win95-start', 'win95-start'],
  ['win95-programs', 'win95-programs'],
  ['win95-program-items', 'win95-program-items'],
  ['win95-settings', 'win95-settings'],
  ['win95-taskbar-context', 'win95-taskbar-context'],
  ['win95-task-context', 'win95-task-context'],
  ['win95-my-computer', 'win95-my-computer'],
  ['win95-group', 'win95-group'],
  ['win95-folder-small', 'win95-folder-small'],
  ['win95-folder-list', 'win95-folder-list'],
  ['win95-folder-details', 'win95-folder-details'],
  ['win95-folder-multiselect', 'win95-folder-multiselect'],
  ['win95-folder-context', 'win95-folder-context'],
  ['win95-window-inactive', 'win95-window-inactive'],
  ['win95-window-maximized', 'win95-window-maximized'],
  ['win95-window-minimized', 'win95-window-minimized'],
  ['win95-menubar', 'win95-menubar'],
  ['win95-system-menu', 'win95-system-menu'],
  ['win95-move-outline', 'win95-move-outline'],
  ['win95-size-outline', 'win95-size-outline'],
  ['win95-find', 'win95-find'],
  ['win95-find-results', 'win95-find-results'],
  ['win95-find-date', 'win95-find-date'],
  ['win95-find-advanced', 'win95-find-advanced'],
  ['win95-run', 'win95-run'],
  ['win95-shutdown', 'win95-shutdown'],
  ['win95-wizard', 'win95-wizard'],
  ['win95-properties', 'win95-properties'],
  ['win95-message', 'win95-message'],
  ['win95-scale2', 'win95-scale2'],
  ['win95-scale3', 'win95-scale3'],
  ['win95-scale4', 'win95-scale4'],
  ['win95-remainder', 'win95-remainder'],
  ['win95-dpi125', 'win95-dpi125']
]

for (const [view, name] of scenarios) {
  const artifact = path.join(root, 'artifacts', `${name}.png`)
  const baseline = path.join(root, 'tests', 'visual', 'baselines', `${name}.png`)
  fs.mkdirSync(path.dirname(artifact), { recursive: true })
  fs.mkdirSync(path.dirname(baseline), { recursive: true })
  const args = [path.join(root, 'scripts', 'capture-wfw.cjs'), artifact, view]
  if (!update) args.push(baseline)
  process.stdout.write(`${update ? 'updating' : 'testing'} ${name}... `)
  const result = spawnSync(electron, args, { cwd: root, stdio: 'inherit' })
  if (result.status !== 0) process.exit(result.status ?? 1)
  if (update) fs.copyFileSync(artifact, baseline)
}
console.log(`${scenarios.length} Win95 visual scenarios ${update ? 'updated' : 'passed'}.`)
