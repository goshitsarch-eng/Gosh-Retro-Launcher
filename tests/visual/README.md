# Visual regression baselines

`baselines/*.png` are renders produced by the **Electron/React build (1.0.6)** and are the pixel reference the
Godot build is measured against:

* `wfw-reference.png` (511x335), `wfw-desktop.png`, `wfw-desktop-minimized.png` - Windows for Workgroups 3.11.
* `win95-*.png` - 39 deterministic Windows 95 RTM scenarios: desktop states, Start menu cascades, taskbar contexts,
  folder views, window states, menus, Move/Size outlines, Find, Run, Shut Down, wizard, property sheet, message box,
  and 2x/3x/4x, non-divisible 1281x961, and 125% DPI captures.

## Running

```bash
# one scenario: renders the real app with a deterministic fixture profile and drives it with injected input
godot --path . -- --capture=win95-start --out=artifacts/win95-start.png
python3 tests/visual/compare.py artifacts/win95-start.png tests/visual/baselines/win95-start.png --diff artifacts/diff.png
```

`compare.py` applies the original rule: identical dimensions and at most 0.5% of pixels differing by more than 20 per
channel. The diff image shows actual | baseline | difference (magenta).

Scenarios live in `scenarios.gd`, fixtures in `fixtures.gd`, and the element ids they click are listed in
`AUTOMATION_IDS.md`. Extra views without baselines: `switch-to-win95`, `switch-roundtrip` (runtime shell switching),
`file`, `options`, `window`, `help`, `item-selected`, `group-maximized`, and the WfW dialog views.

## Known, expected differences

The committed baselines were rendered on a machine with a user-supplied, gitignored pack of licensed Windows icons and
fonts (`assets/win95-rtm-local`, `assets/wfw-rtm-local`) and with Chromium text rasterization. The distributable build
ships clean-room icons and fonts instead, so icon pixels and glyph shapes differ by design: layout, colours, bevels,
and positions match, and most views land at 0.7-3% differing pixels rather than under 0.5%. If you have the local packs,
drop them in those folders and the Godot build uses them (icons and, for Windows 95, the MS Sans Serif atlas), which
is the configuration the baselines were captured with.
