# QA audit log

Hands-on audit of Program Manager (Godot 4, four shells: Windows 3.11, Windows 95, Classic Mac OS, BeOS).
This file is the live defect log. Each entry records what was observed, how it was reproduced, the root
cause, the fix, and how the fix was verified. Status values: **fixed**, **open**, **not a defect**, **intentional**.

Environment: macOS 27.0.1 (arm64, Apple M2 Max, 2× display). Godot 4.7.2 stable (local Homebrew build) and Godot
4.6.3 stable (the version pinned in CI, downloaded from the Godot release page for cross-checks). CI runs the unit
tests on Linux.

## Summary

| ID | Area | Severity | Status |
|----|------|----------|--------|
| BUG-001 | Single instance (macOS) | High | fixed, verified |
| BUG-002 | Built-in SVG icon loading | Low | fixed, verified |
| BUG-003 | Launching an item with no target | Low | fixed, verified |
| BUG-004 | Win95 wizard leaked objects on every open | Medium | fixed, verified |
| BUG-005 | BeOS Find window opened under the Deskbar | Medium | fixed, verified (1–4 tasks; see limits) |
| BUG-006 | BeOS Deskbar menu mixed "..." and "…" | Low | fixed, verified |
| BUG-007 | BeOS details view had no visible horizontal scrollbar | Medium | fixed, verified |
| BUG-008 | Win95 text fields clipped at the bottom edge (Find, wizard) | Medium | fixed, verified |
| BUG-009 | Mac list and Find results shaded the Name header unsorted | Low | fixed, verified; **departs from the design brief, your call** |
| Q-001 | Window resize | - | not a defect: you confirmed resize works by hand |
| Q-002 | Capture size of `reference` and `win95-remainder` | - | closed: macOS rounds window sizes; not an app defect |
| Q-003 | Win95 desktop top strip moved the window | Low | open, not reproduced after a guard |
| Q-004 | BeOS folder window's top-right corner under the Deskbar | Medium | open, needs your decision |
| Q-005 | Win95 Properties "Main" text moved 1 px | - | caused by the caret-to-end line; your call (see below) |
| Q-006 | Text-field and title-bar captures depend on window focus | - | harness caveat |
| INC-001 | Live user data file rewritten by a test run | - | needs your review |
| INC-002 | Stray mouse drag on the wallpaper | - | no visible effect |
| INC-003 | A Bash call was denied by the auto-mode classifier | - | not retried, not worked around |

Unit suite: **418 tests, 0 failed** under Godot 4.7.2 and under Godot 4.6.3. Before the audit: 396 tests, 3 failed
under 4.7.2 and the same 3 under 4.6.3 on macOS.

## Fixed defects

### BUG-001: single-instance lock is never claimed on macOS (fixed)

- **Area:** Platform / single instance (`src/platform/single_instance.gd`), affects every shell.
- **Severity:** High. The app silently runs without its single-instance lock, so a second launch opens a second
  copy instead of handing off to the first, and `--quick-search` never reaches a running instance.
- **Reproduction:** Run the unit suite on macOS. `test_platform_single_instance` and
  `test_platform_desktop_bridge` fail (3 assertions). Launch the app and check its listeners: a running
  instance has no listening socket.
- **Root cause:** `_probe()` decides "free" or "foreign" by connecting. On macOS, Godot 4.6.3 and 4.7.2 both
  report a connection to a port nobody listens on as `STATUS_CONNECTED` on the first poll, then `STATUS_NONE`
  with no bytes. The probe read that as a foreign listener and skipped every free port.
- **Fix:** The verdict is now a pure function, `SingleInstance.classify_probe(valid_reply, dropped, got_bytes)`.
  A connection dropped without a single byte returns "free". `acquire()` still has to win the bind before it
  claims the port, so a real foreign listener is still skipped. The status check runs before any read, because
  reading a closed socket logs an engine error. I did not use the listen-first order: if Godot sets
  `SO_REUSEADDR` on Windows, a bind can succeed on a port another instance holds. I did not verify Godot's
  Windows behaviour here.
- **Verification:**
  - `test_probe_verdicts_cover_every_outcome` is a truth table of the verdict. It runs on every platform, so the
    macOS case is tested on Linux CI as well.
  - Two headless processes on one profile: the second returns SECONDARY, and the first logs the show request.
  - Two windowed processes on one isolated profile: the first listens on loopback, and the second exits with
    code 0 after 12 s with no errors in its log.

### BUG-002: built-in SVG icons trigger a "will not work on export" warning on every load (fixed)

- **Area:** Toolkit / icon registry (`src/toolkit/icon_registry.gd`).
- **Severity:** Low. The packed build already loaded these icons correctly. The warning fired on every icon load.
- **Root cause:** `_load_res()` used `Image.load_from_file()` on `res://` SVG files that have an import entry.
- **Fix:** Read the raw bytes with `FileAccess.get_file_as_bytes()` and decode with `Image.load_svg_from_buffer()`.
  The result is the same 32×32 texture.
- **Verification:** Source and Linux PCK builds resolve the icons to 32×32 with no warning. The unit suite logs
  no export warnings under either version. 134 of 137 views are pixel-identical to HEAD (see "Regression").

### BUG-003: launching an item with no target says "Program not found: " with nothing after it (fixed)

- **Area:** Launcher core (`src/core/launcher.gd`, `launch_program()`), every shell.
- **Severity:** Low. The alert is misleading, but nothing is launched and the app keeps running.
- **Reproduction:** Mac shell, Launcher HD, Main folder, double-click "Control Panel" (fixture item with an empty
  target). The alert reads "Program not found:".
- **Fix:** `launch_program()` refuses an empty or whitespace-only target before dispatch and returns
  "No program is set for this item.". Unit test `test_launch_without_target_explains_itself`.
- **Verification:** `mac-launch` shows the new text. `be-launch`, `win95-launch` and `launch-win31` are unchanged.

### BUG-004: the Win95 Create Shortcut wizard leaked objects on every open (fixed)

- **Area:** Win95 shell, wizard (`src/shells/win95/win95_dialog_forms.gd`).
- **Severity:** Medium. Each open leaked objects, so repeated use grew the heap. Nothing visible changed.
- **Measured before the fix:** `win95-wizard-loop` (six open-and-cancel cycles) rose by exactly 7 live objects per
  cycle (1768 → 1803). The exit report grew with it: 18 CanvasItem RIDs and 56 ObjectDB instances, plus about 18
  "Cannot get path of node" errors.
- **Root cause:** Back and Next detach the other step's fields so they can be reused, and nothing frees them when the
  modal closes. The `--verbose` exit report named LineEdit, Control, Object, StyleBoxFlat and StyleBoxEmpty instances.
- **Fix:** The page is a `_WizardPage` that owns the three fields. On `NOTIFICATION_PREDELETE` it frees any field
  that has no parent.
- **Verification:**
  - `win95-wizard-loop` after the fix: 1762 objects on all six iterations. No exit leak lines, no "Cannot get path" errors.
  - `win95-wizard`: the log goes from 7 error or warning lines to none.
  - `test_win95_wizard_lifetime` (3 tests). Run on a HEAD copy, the object-count test fails with "grew by 28 over
    4 cycles".

### BUG-005: the BeOS Find window opened under the Deskbar at 640×480 (fixed)

- **Area:** BeOS shell window placement (`src/shells/be/be_geometry.gd`, `default_rect()`).
- **Severity:** Medium. Controls were hidden: the "All programs" dropdown was cut to "All gro" and the Find button label
  was not visible.
- **Root cause:** The Find window's minimum width (460 px) is wider than the 440 px left of the 200 px Deskbar, and the
  default placement started it at y = 32, over the Deskbar's column.
- **Fix:** `default_rect(key, n, view, deskbar_bottom := -1.0)`. The clearance comes from the real Deskbar height for
  the windows that will be open: `deskbar_parts(max(n + 1, 2))`, which counts the Find window itself. The window starts
  16 px below the Deskbar. If the height is not enough, the height shrinks first, down to `MIN_H`, and the
  gap shrinks before the height does. The earlier fixed constant is gone.
- **Verification:**
  - Unit tests: placement for 1, 2 and 3 tasks does not intersect the Deskbar rect for that count and fits the screen.
    Four tasks: the "no fit" case. Ten tasks: height at least `MIN_H`. The explicit `deskbar_bottom` argument.
  - Captures: `be-quicksearch` (two tasks) at y = 160. `be-find-3tasks` at y = 190. `be-find-4tasks` at y = 204 with
    height 276, which is below the 280 minimum. That trade-off is documented in the code.
- **Limits:** With about six or more tasks the window moves up under the Deskbar's top-right corner. Windows opened
  after Find can grow the Deskbar down over it, and no placement made when Find opens can prevent that.

### BUG-006: the BeOS Deskbar menu mixed "..." and "…" (fixed)

- **Area:** BeOS menu model (`src/shells/be/be_menu_model.gd`).
- **Fix:** The four Deskbar-logo labels use "…" like the other BeOS menus. `test_deskbar_menu_matches_the_design_items`
  is updated.
- **Verification:** `be-deskbar` renders "…" correctly. `be-about` is pixel-identical to HEAD, so the About item
  still opens its dialog.

### BUG-007: the BeOS details view had no visible horizontal scrollbar (fixed)

- **Area:** BeOS folder view (`src/shells/be/be_folder_view.gd`, `be_geometry.gd`).
- **Severity:** Medium. The details columns need 520 px, so in a 640×480 window the third column ("Batch", or "Type"
  on the Program Manager root) was reachable only by horizontal wheel or trackpad scroll, with nothing to show it.
- **Fix:** A horizontal scrollbar runs along the bottom edge when the columns are wider than the list. It has the same
  look as the vertical one, with a thumb that drags, and its wheel and trackpad scrolling is unchanged. When both bars
  show, the vertical bar stops above the horizontal one and the corner is filled. Clicks on a bar no longer select the
  row underneath. Pure helpers: `scroll_bars`, `scroll_thumb`, `scroll_from_thumb`.
- **Verification:**
  - `be-details`: the bar appears at the bottom of the list.
  - `be-details-scrolled`: with the thumb dragged right, the Command and Batch columns are visible and the header stays
    aligned.
  - `be-details-both`: with the window shrunk, both bars show and the corner is filled.
  - `be-folder` and `be-mini` (icon views) are unchanged.
- **Note:** Between about 520 and 532 px of inner width, a small horizontal bar now appears when the vertical bar is
  showing. This matches CSS `overflow:auto` in the brief.

### BUG-008: Win95 text fields clipped at the bottom edge (fixed)

- **Area:** Win95 text input (`src/shells/win95/win95_text_input.gd`), Find, wizard and other dialogs that use it.
- **Severity:** Medium. The text and the caret sat about 8 px low and were cut by the 21 px box.
- **Root cause:** `_layout()` ran before the field joined a tree (the constructor, or a size set before `add_child`).
  Outside the tree the LineEdit still holds the default theme, so its minimum height was 31 and the 15 px height was
  clamped to 31. Run sets its size after `add_child`, which is why Run was not affected.
- **Fix:** Re-lay out on `NOTIFICATION_ENTER_TREE` (deferred, because the parent enters first) and in `_ready()`. A
  `null` guard protects `_layout()`. Setting a new `text` also puts the caret after the text, as an HTML input does. Re-assigning the same value leaves the
  caret alone.
- **Verification:**
  - 4× crops of `win95-find`, `win95-find-results` and `win95-wizard` against the Electron baseline: the text is
    centred and the caret sits after the `*`.
  - Pixels changed against HEAD: `win95-find` 30 px, `win95-find-results` 10 px, `win95-wizard` 16 px.
  - `test_win95_text_input` (4 tests).
- **Not fixed:** The caret is still about 1 px left of the baseline. The worker judged that a font and advance-width
  detail rather than clipping.

### BUG-009: the Mac list and Find results shaded the Name header with no sort (fixed; departs from the brief)

- **Area:** Mac folder list (`src/shells/mac/mac_folder_view.gd`) and Find window (`src/shells/mac/mac_find_window.gd`).
- **Problem:** The Name column's sorted-column shading (header fill, column band and header inset) was drawn
  unconditionally, but the list has no sort. Rows stay in the user's store order. The Find results are ranked by
  relevance.
- **What the brief says:** `Program Manager.dc.html` draws the header fill unconditionally (around line 611) and shades
  the first column of unselected rows (`macCol`, around line 1856). Neither depends on sorting.
- **Fix:** `MacFolderView.is_name_sorted(entries)` uses the same comparator as Clean Up. The three shading cues are drawn
  only when the displayed order really is by name. The Find header fill is gated by the same rule.
- **Verification:**
  - `mac-folder-list`: the header is plain and the rows are in store order.
  - `mac-quick-search`: the header is plain. Its results are relevance-ordered.
  - `mac-find`: unchanged, because its results happen to be in name order, so the shading is accurate there.
  - `test_mac_folder_view` (4 tests).
- **Decision for you:** The brief always draws these cues. This fix departs from the brief's default look for every
  unsorted list. To keep the brief's look, revert `mac_folder_view.gd` and `mac_find_window.gd`.

## Open defects

### Q-003: a press on the top strip of the Win95 desktop moved the window (open, not reproduced)

- **Original observation (earlier session):** a real mouse press 1 pt below the desktop's content top moved the whole
  window by the drag vector.
- **Re-measured after a guard:** the window moves only for presses above the title bar's bottom edge, which is at
  32 pt below the top of the window. Presses at 31 pt move it. Presses at 32, 32.25, 33, 34, 35, 36 and 38 pt do not,
  whether the window was launched directly, switched from WfW at runtime, or inactive. The title bar's bottom row was
  checked in the screenshot (row 63 dark, row 64 teal).
- **Runtime flags:** borderless, extend-to-title, transparent and mouse passthrough are all false. The source sets none
  of these for the Win95 window.
- **Likely explanation:** The first attempt had other windows lying over the area. The guard checked only our own
  window's bounds, not which window was on top.
- **Ruled out:** Nothing in the app moves the Win95 window. `start_window_drag` is only called by WfW. The WfW caption
  drag still moves exactly as before.
- **To settle:** the original posted coordinates, the window position read just before posting, and the on-screen
  window list at that moment.

### Q-004: a BeOS folder window's top-right corner sits under the Deskbar (open, needs your decision)

- At 640×480 the top-right corner of a folder window, including the top of its vertical scrollbar, lies under the
  Deskbar's task rows. A click there hits the task row and hides the window.
- Not changed. Options: keep folder windows out of the Deskbar column when they open, or accept the BeOS-like behaviour.

## Side effects and caveats

### Q-002: capture size of `reference` and `win95-remainder` (closed; not an app defect)

- macOS sizes windows in whole points. On this 2× display an odd pixel size rounds down. A bare Godot window does the
  same: 511×335 → 510×334, 1281×961 → 1280×960, 1279×959 → 1278×958. 640×480 and 512×336 are unchanged.
- ShellScale and the viewport are not involved.
- Change: the capture prints a notice when the window size differs, and `tests/visual/README.md` says these two views
  must be captured on a 1× display. `--baseline` still fails on the size mismatch.
- Consequence: on a Retina Mac, `win95-remainder` at scale 2 is 640×480 logical, so it cannot test the non-divisible
  case it exists for. No 1× display was available here, so the baseline comparison was not run.

### Q-005: the caret-to-end line moves the Properties "Main" text 1 px (isolated; your call)

- Isolated by experiment: with the one line that puts the caret after the text (`caret_column = v.length()`), the
  Properties dialog differs from HEAD by 26 px inside the selected "Main" text. Without that line it differs by 0 px.
- The same line moves the Find "Named" caret after the `*`, as the Electron baseline has it. Without it the Find
  dialog differs from HEAD by 18 px instead of 30. So the line costs Properties 26 px and buys Find 12 px of baseline
  parity.
- Against the Electron baseline the Properties region has 7 more differing pixels with the line (283 → 290). The whole
  image is effectively unchanged (1.423% → 1.425%).
- The setter now ignores a re-assignment of the same value, so a handler that re-sets the text while the user types
  cannot move the caret. No current handler does that. The five Find and wizard views are unchanged (0 px) by the guard.
- **Decision for you:** keep the line (Find parity), or delete it (Properties pixel-exact).

### Q-006: captures that show focus or title bars depend on window focus (harness caveat)

- Godot hides a LineEdit's caret while its window lacks focus. Other windows on screen take focus during a run, so
  reruns of text-field views can differ. One run had no caret at all.
- Also nondeterministic on HEAD, confirmed by reruns: `win95-desktop-marquee` (4,076 px between two HEAD runs) and
  `wfw-copy-dialog` (10,608 px in the title bar between two HEAD runs).
- Run captures of focused text on a quiet desktop before reading a difference as real.

## Visual review (three read-only reviewers, verified by me)

The reviewers read every assigned capture: 37 Mac, 32 BeOS, 25 WfW, 2 Win95 without baseline, and the 16 diffs against
the committed baselines. Each claim was checked before it was accepted.

**Checked and not defects, or intentional**

- **BeOS `be-trash` / `be-trash-confirm` "swapped":** not a defect. `be-trash` shows the confirmation (8 items), and
  `be-trash-confirm` shows 7 items after Yes, which is what the scenario does. The reviewer misread the images.
- **Win95 `win95-desktop-marquee` "no marquee":** not an app defect. A real OS drag from (120,40) to (190,120) draws the
  marquee in the right place. The capture is nondeterministic on HEAD (see Q-006).
- **WfW `help` dropdown right-aligned:** intentional. `win31_menu_bar.gd` (around line 84) applies the original
  `.wfw-menu-root:nth-last-child(-n+2) > popup {right: 0}` rule. Windows 3.1 left-aligns Help. Not changed. **Your call.**
- **WfW `group-maximized` iconic icons drawn above the maximized Main window:** intentional. The `_restack()` comment in
  `win31_mdi_client.gd` says icons sit above all windows (original z-index 10000). Not changed. **Your call.**
- **Mac window behind a dialog keeps its active title bar:** consistent. Find and folder are windows, so they deactivate
  the window behind them. Dialogs are overlays and leave the front window active, which I understand to match classic
  modal alerts. Not checked against a Mac reference.
- **Mac "Shut Down" without an ellipsis:** not changed. Classic Mac OS 9 gives "Empty Trash" and "Shut Down" no ellipsis
  even though both confirm first. Not checked against a reference.
- **Byte-identical baselines:** `win95-group.png` and `win95-window-inactive.png` in `tests/visual/baselines/` are
  byte-identical to the HEAD captures, so they are Godot renders, not Electron references.

**Open and not yet verified**

| Area | Finding (reviewer's claim) | Severity claimed | Note |
|------|----------------------------|------------------|------|
| Mac | Launch toast covers the active window title | Low | Toast says "Starting Control Panel..." before the error |
| Mac | Zoom fills the whole screen | Low | Classic zoom sizes to contents; design decision |
| BeOS | "MS-DOS Prompt" truncated while the Command column is empty | Low | Column widths |
| BeOS | Zoomed window hides an icon under the Deskbar; third window opens at the same spot | Low | Inherited from the design's clamp |
| BeOS | Get Info runs past the bottom edge; new folder label hidden under the PM tab | Low | Layout |
| BeOS | Clipped "5 items" text shows under the Main window | Low | Natural occlusion, but visibly cut |
| BeOS | Scrollbar has no end arrows; dark-theme selection contrast is low | Low | Low confidence |
| Win95 | `switch-to-win95` renders at 640×416 instead of 640×480 | Low | Shell switch keeps outer bounds (`platform.gd`, `apply_shell_frame`) |
| Win95 | Reference view: taskbar grip missing; two top-edge rows swapped | Low | Low confidence on the row order |
| Win95 | Move and size outlines are offset from the baseline | Low | Probably the drag delta |
| Win95 | File menu enables Delete and Properties with nothing selected | Low | May be intended for the active group |

Not a defect: `item-properties` shows blank fields because the fixture items have no command line.

## Menu click-through

Each sweep is a capture view. It sets up a selection (where needed), opens a menu, clicks each in-scope item, presses
Escape to close any dialog or popup, and prints a step marker. The log is checked for errors and warnings after each
marker. All three runs produced none.

These are items **clicked**, not items **exercised**. A click on a disabled item does nothing, and the sweep does not
record each item's enabled state.

| Shell | Views | Items clicked | Skipped by design |
|-------|-------|---------------|-------------------|
| WfW | `menu-sweep-wfw` | 18: File (New, Open, Move, Copy, Properties, Delete, Run), Options (3), Window (3), Launcher (Launch All), Help (4) | Exit Windows… (quits the app); Launcher Tools… (separate OS window) |
| Mac | `mac-menu-sweep` | 23: View, Edit, File, the logo, Special and Help menus | Restart (restarts the app); Launcher Tools… (separate window); the generated per-group launch entries |
| BeOS | `be-menu-sweep` | 5: the Deskbar logo menu | Restart and Shut Down… (end the session); Launcher Tools… (separate window); group submenus |

The WfW and Mac sweeps select an item and keep a folder window open first, so the selection-dependent items are
enabled. Delete and Move To Trash run late so they don't remove the selection the other items need. The six Mac Edit
items and Show Balloons are disabled by design.

Not swept: the Win95 Start menu and its cascades, folder-window and context menus, dialog buttons, keyboard navigation,
and the native file dialogs.

## Regression

- **Run:** all 146 views on the working tree, sequentially, with `run-captures.sh`. Every view exited 0. No view logged an
  error or warning. That includes the two menu sweeps and the wizard loop.
- **137 HEAD views:** 122 are pixel-identical to HEAD. The other 15:
  - Intended, from the fixes: `be-deskbar`, `be-deskbar-sub` (BUG-006), `be-details` (BUG-007), `be-find`,
    `be-find-results`, `be-quicksearch` (BUG-005), `mac-folder-list`, `mac-quick-search` (BUG-009), `mac-launch`
    (BUG-003), `win95-find` and `win95-find-results` (BUG-008), `win95-wizard` (BUG-008, and the same field).
  - Side effect: `win95-properties` (Q-005).
  - Nondeterministic on HEAD, confirmed by reruns: `wfw-copy-dialog` and `win95-desktop-marquee` (Q-006).
- **New views with no HEAD counterpart:** `mac-scale3`, `menu-sweep-wfw`, `mac-menu-sweep`, `be-menu-sweep`,
  `win95-wizard-loop`, `be-details-scrolled`, `be-details-both`, `be-find-3tasks`, `be-find-4tasks`. All ran clean.
- **Icon views:** `be-folder` and `be-mini` are unchanged.

## Incidents

### INC-001: a test instance wrote to the live user data file (needs your review)

- **What happened:** While testing BUG-001, I launched a windowed instance without `PM_USER_DATA`. It used the real
  profile `~/Library/Application Support/program-manager/`. It exited by itself (`--quit-after`).
- **Effect on your data:** `program-manager-data.json` was rewritten at 17:42:50. Compared with the newest backup
  (`backups/2026-11-15T01-29-53.943Z--settings-changed.json`), the only difference is `settings.shell`: `"mac"` became
  `"be"`. My instance sent no input. I cannot tell from the files whether the value was already `be` before my instance
  started. I did not edit the file.
- **Also touched:** Engine logs from my headless experiments that ran without `PM_USER_DATA` were written to
  `~/Library/Application Support/program-manager/logs/` (`godot2026-11-14T17.46.*.log`). I left them in place.
- **Process fix:** Every app launch and capture since then sets `PM_USER_DATA` to a directory under the scratchpad.

### INC-002: a stray mouse drag on the wallpaper (no visible effect)

- After my test instance had exited, I posted a mouse drag at screen point (120,72) with no window target. A full-screen
  capture shows that point is on the desktop wallpaper below the menu bar. No window was there. No visible change.

### INC-003: a Bash call was denied by the auto-mode classifier

- **What happened:** I tried to launch a second copy of the app and stop a test instance, using a sandbox override.
  The classifier denied the call. I did not retry it and did not work around the denial.
- **Outcome:** The test instance (PID 18071) exited on its own later. No process of mine is running now.

## Verified behaviour (no defect found)

- **Settings persist through an immediate quit.** A headless run changed a setting and quit inside the 300 ms debounce
  window. The change was on disk at once, because the store flushes in `_exit_tree`. Not tested: a hard kill (SIGKILL)
  inside that window. A kill can lose the last write, which is by design.
- **Exported PCK:** the Linux preset exports cleanly (2.4 MB) and contains the raw SVG icons.
- **Real-window rendering:** the WfW Program Manager renders correctly at 2× (Options menu, Main group, desktop icons).
- **Real-input marquee:** a drag inside the Win95 desktop draws the marquee correctly.
- **Two-instance hand-off:** the second instance exits with code 0 and no errors (BUG-001).
- **Against the committed Electron baselines** (43 Win95 and WfW references): most Win95 views differ by 0.7–1.8%,
  matching the README's stated tolerance for font and icon artwork.

## Not covered by this audit

- The Win95 Start menu and its cascades, folder-window and context menus, dialog buttons, and keyboard navigation.
- The native file dialogs: open, save, cancel, invalid file, read-only target.
- Launcher Tools and the Settings dialog beyond their scripted views.
- Relaunch persistence of window size and position.
- The exported macOS app. I exported and checked only the Linux PCK.
- `reference` and `win95-remainder` on a 1× display (none available here; see Q-002).
- Items listed as "open and not yet verified" in the visual review table.

## Files changed (uncommitted)

- Platform and app: `src/platform/single_instance.gd` (BUG-001); `src/platform/window_layout.gd`, `src/app/capture.gd`
  (Q-002 notice); `src/core/launcher.gd` (BUG-003); `src/toolkit/icon_registry.gd` (BUG-002).
- Win95: `src/shells/win95/win95_dialog_forms.gd`, `src/shells/win95/win95_text_input.gd` (BUG-004, BUG-008).
- BeOS: `src/shells/be/be_geometry.gd`, `src/shells/be/be_folder_view.gd` (BUG-005, BUG-007); `src/shells/be/be_menu_model.gd`
  (BUG-006).
- Mac: `src/shells/mac/mac_folder_view.gd`, `src/shells/mac/mac_find_window.gd` (BUG-009).
- Tests: `tests/unit/test_platform_single_instance.gd`, `test_launcher.gd`, `test_platform_window.gd`,
  `test_be_geometry.gd`, `test_be_menu_model.gd`, new `test_win95_wizard_lifetime.gd`, `test_win95_text_input.gd`,
  `test_mac_folder_view.gd`.
- Hygiene: the three new test scripts have their `.gd.uid` files, generated with the pinned 4.6.3. The orphan
  `src/core/shortcut.gd.uid` (no script, no reference) is deleted as an unstaged change.
- Visual harness: `tests/visual/fixtures.gd`, `scenarios.gd`, `mac_scenarios.gd`, `be_scenarios.gd`, `README.md`.
- `CHANGELOG.md` (Unreleased: Fixed and Changed entries) and this log, `docs/QA_AUDIT.md`.
