# Godot port: working contract

This repo was rewritten from Electron/React to **Godot 4.6 (GDScript)**. The original TypeScript sources
(`src/main`, `src/preload`, `src/renderer`, `src/shared`) were deleted once the port reached parity; they remain in git
history at commit `3b861ff` (`git show 3b861ff:src/renderer/src/...`) and are the specification that code comments
such as "Port of shells/win95/menuState.ts" refer to. The Godot project lives at the repo root (`project.godot`).

## Layout

```
project.godot
assets/            fonts (Win95Sans/WfWSans), wfw/ and win95/ icon PNGs (moved from src/renderer/src/assets)
src/core/          pure logic + stores (done, tested): Types, Jsonx, Migration, Grp, Launcher, LnkFile,
                   Validators, Persistence, LaunchGroups, ProgramSearch, autoloads ProgramStore/UIState/MdiState
src/toolkit/       drawing toolkit (done): RetroFont, Px, Pal, ShellScale, Assets
src/app/           main.gd (host), platform.gd (autoload "Platform" = old main process/preload),
                   automation.gd + capture.gd (visual harness)
src/shells/        shell_base.gd (contract), win31/, win95/
tests/unit/        test_*.gd (extend TestCase), run by tests/run_tests.gd
tests/visual/      baselines/*.png (ORIGINAL Electron renders), scenarios.gd, fixtures.gd, compare.py
```

## Rules

1. **Own files only.** You are given a set of files/dirs you own. Never edit anything else (read freely).
   If you need a change in shared code (`src/core`, `src/toolkit`, `src/app`, `src/shells/shell_base.gd`),
   do the minimum *additive* change and report it in your final summary. Never rename/remove public API.
2. **Port behavior, not just looks.** The TS/TSX/CSS under `src/renderer/src/**` is the spec. Port every
   state machine, keyboard path, edge case and *its unit tests* (vitest -> `tests/unit/test_*.gd`).
3. **Pixel fidelity.** Both shells are pixel-exact emulations. Everything is drawn in **logical pixels**
   with integer coordinates; the host applies one integer content scale (1x-4x, nearest filtering).
   Never use fractional coordinates, anti-aliased shapes, or Godot's default Theme look. Use
   `Px` (bevels/lines/dither/focus rect), `Pal`, and `RetroFont.draw()` for **all** text.
   Win95 metrics are in `src/shells/win95/tokens.gd`; Win31 in `src/shells/win31/tokens.gd`.
4. **Custom drawn controls**: subclass `Control`, draw in `_draw()`, handle `_gui_input`. For things that
   need global pointer tracking (menu press-drag-release, move/size outlines) use `_input()` on the shell
   root. Call `queue_redraw()` on state change (project runs in low-processor mode, nothing redraws by itself).
   Text input may use `LineEdit` with a flat transparent StyleBox and the pixel FontFile from `RetroFont`
   (`RetroFont.instance(...).font`), drawn into your own bevel frame.
5. **State via autoloads only**: `ProgramStore` (groups/settings/profiles; mutate through its methods, listen
   to `groups_changed`/`settings_changed`), `UIState` (dialogs/menus/selection/quick search/launch feedback),
   `MdiState` (Win31 group windows), `Platform` (launch, native dialogs, window control, app info, URLs).
6. **Automation ids** (see `tests/visual/AUTOMATION_IDS.md`): every interactive element the scenarios touch must
   be discoverable (`auto_lookup` / meta `auto_id`, group `pm_auto`). Add ids freely beyond that list.
7. **Capture clock**: when `Engine.has_meta("pm_capture")` the Win95 tray clock shows
   `Engine.get_meta("pm_capture_clock")` ("12:00 PM") instead of the real time.
8. GDScript style: tabs, typed where cheap, `class_name` for anything referenced from another file,
   comments only for non-obvious intent. No `await` inside `_draw`.

## Commands (this sandbox)

```
S=/tmp/claude-0/-home-user-Gosh-Retro-Launcher/5a2699b9-b591-57e6-9a09-de7612df2084/scratchpad
$S/gtestw <worktree> [filter]          # headless unit tests (fails on script/parse errors too)
$S/gshotw <worktree> <view> [view...]  # render real app under Xvfb -> <worktree>/artifacts/<view>.png
                                       # + diff vs tests/visual/baselines/<view>.png -> artifacts/<view>.diff.png
$S/gdw <worktree> <godot args>         # raw headless godot (e.g. --headless --script x.gd)
```

`<worktree>` is your own checkout root. Look at `artifacts/*.diff.png` with the Read tool
(left=actual, middle=baseline, right=diff, magenta = differing pixels) and crop/zoom with PIL
(`Image.crop(...).resize(..., Image.NEAREST)`) to compare details. The baselines were rendered by the
Electron app; text may differ slightly (different font rasterizer) — judge layout/colour/geometry exactly,
glyph AA noise loosely. The pass rule is <=0.5% of pixels differing by >20/channel; aim for that, and
where text noise alone prevents it, report the measured number.

Rendering notes verified in this environment: GL Compatibility via Mesa llvmpipe; `content_scale_factor`
in `disabled` mode scales the logical canvas exactly; `FontFile` with `antialiasing=NONE, hinting=NONE`
gives crisp 1-bit glyphs and 2x is a pixel-exact enlargement of 1x.

## Reporting

Finish with: files created, tests added (names + counts), screenshot views you matched and their measured
diff %, anything you could not port or had to approximate (be explicit — hidden gaps are regressions),
and any additive edits made to shared files.
