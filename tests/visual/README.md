# Visual regression baselines

`baselines/*.png` are renders produced by the **Electron/React build (1.0.6)** and are the pixel reference the
Godot build is measured against:

* `wfw-reference.png` (511x335), `wfw-desktop.png`, `wfw-desktop-minimized.png` - Windows for Workgroups 3.11.
* `win95-*.png` - 40 Windows 95 PNG baselines (an earlier version of this README said 39): desktop states, Start menu cascades, taskbar contexts,
  folder views, window states, menus, Move/Size outlines, Find, Run, Shut Down, wizard, property sheet, message box,
  and 2x/3x/4x, non-divisible 1281x961, and 125% DPI captures.

## Running

Captures choose a temporary profile when `PM_USER_DATA` is not set (CORE-14 is fixed; checked with HOME set to a temporary folder). Still set it in your own scripts. `compare.py` needs numpy and Pillow. The view `wfw-settings` captures the settings dialog from Options. The `*-notice` names (`win95-notice`, `wfw-notice`, `mac-notice`, `be-notice`) have no scenario of their own, so they capture the shell's default state. With `PM_CAPTURE_NOTICE=1`, every capture run posts one sample save-failure notice (`_post_capture_notice` in `src/app/main.gd`), so the shell's message box can be checked. The 2026-11-14 comparison results are in the handbook's coverage chapter: no baseline passed.

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

Menu sweeps and a leak probe print `SWEEP` or `WIZARD_LOOP` markers. Errors printed after a marker belong to that step:
`menu-sweep-wfw`, `mac-menu-sweep` and `be-menu-sweep` click each in-scope menu item and press Escape after it.
`win95-wizard-loop` opens and cancels the Create Shortcut wizard six times and prints the object count each time.
Skipped items (quit, restart, separate OS windows) are listed in the comments beside each sweep.

`reference` and `win95-remainder` use odd window sizes. On a 2x macOS display the OS rounds them down to whole points, so
they come out 1 px smaller per axis, and `--baseline` reports a size mismatch. Capture them on a 1x display to compare
them with their baselines. The capture prints a notice when this happens.

BeOS scroll and placement views: `be-details-scrolled` (horizontal scrollbar dragged right), `be-details-both` (both
scrollbars), and `be-find-3tasks` and `be-find-4tasks` (Find window with three and four open windows).

## Known, expected differences

The committed baselines were rendered on a machine with a user-supplied, gitignored pack of licensed Windows icons and
fonts (`assets/win95-rtm-local`, `assets/wfw-rtm-local`) and with Chromium text rasterization. The distributable build
ships clean-room icons and fonts instead, so icon pixels and glyph shapes differ by design: layout, colours, bevels,
and positions match, and most views land at 0.7-3% differing pixels rather than under 0.5%. If you have the local packs,
drop them in those folders and the Godot build uses them (icons and, for Windows 95, the MS Sans Serif atlas), which
is the configuration the baselines were captured with.
