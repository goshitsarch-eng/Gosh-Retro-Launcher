# Architecture

Program Manager is a single-process **Godot 4.6** application written in GDScript. Everything that used to be
split across Electron's main process, preload bridge and React renderer now lives in one scene tree:

```
 ProgramStore / UIState / MdiState / Platform / Sounds   (autoloads: state + system services)
                         │
                  src/app/main.gd  (host: window, scale, shell mounting, tray, single instance)
                         │
        ┌────────────────┴───────────────┐
  Win31Shell (WfW 3.11)             Win95Shell (Windows 95 RTM)
  MDI · menus · dialogs             desktop · taskbar · Start · windows · folder views · Find · dialogs
        └────────────────┬───────────────┘
                 src/toolkit  (RetroFont, Px, Pal, ShellScale, Assets, IconRegistry)
```

## Layers

### Core (`src/core`) — pure logic, fully unit-tested
| File | Role |
|------|------|
| `types.gd`, `jsonx.gd` | Defaults, constants, JSON-model helpers (whole numbers serialize like JavaScript did) |
| `migration.gd` | Normalizes any persisted payload to schema v5 (legacy geometry, scales, positions) |
| `validators.gd` | Strict guards for items, groups, settings, profiles and launch payloads |
| `persistence.gd` | Reads/writes the same `program-manager-data.json` as 1.x (atomic write), versioned backups, corruption recovery |
| `program_store.gd` | Autoload `ProgramStore`: groups, settings, profiles; 300 ms debounced saves (flushed on exit); import/export; backups |
| `ui_state.gd`, `mdi_state.gd` | Autoloads for dialogs/menus/selection/quick search/launch feedback and Win31 window stacking |
| `launcher.gd`, `lnk_file.gd` | Tokenizer, `.desktop` / `.lnk` parsing, environment, per-OS launch and run modes |
| `launch_groups.gd`, `program_search.gd`, `grp.gd` | Batch launching, Quick Search/Find ranking, Windows 3.x `.GRP` codec |

Records are plain `Dictionary`/`Array` values with exactly the keys the Electron build persisted, so data written by
either version is readable by the other.

### Toolkit (`src/toolkit`) — pixel-exact drawing
Both shells are emulations that must match the original systems pixel for pixel, so nothing uses Godot's themed controls
for chrome. Everything is drawn in **logical pixels** with integer coordinates:

* `RetroFont` — 1-bit glyphs from the bundled Win95Sans/WfWSans fonts, positioned glyph-by-glyph with the exact RTM
  advance table (measure/clip/wrap/access-key underlines identical on every machine).
* `Px`, `Pal` — bevels, dither, focus rectangles, canonical palettes.
* `ShellScale` — whole-shell integer scale. The host sets `Window.content_scale_factor` (nearest filtering) so one
  logical pixel is an exact N×N block at 1×–4×.
* `Assets`, `IconRegistry` — texture cache, built-in icon catalog and `icon` string resolution (ids, data URLs, paths).

### Shells (`src/shells`)
`ShellBase` is the contract (`shell_id`, `on_activate`, `toggle_quick_search`, `on_files_dropped`, …). A shell fills the
window's logical area, owns its menus/windows/dialogs, and talks to the model only through the autoloads.
Windows 95 keeps its own primitives and input controller (it never shares presentation code with WfW). Interaction state
machines (`menu_state`, `window_store`, `selection_state`, `list_view_state`, …) are pure and have their own tests.

### Platform (`src/app`, `src/platform`)
`Platform` replaces the old IPC surface: launching, native file dialogs, `.GRP`/JSON import/export, app info and icon
extraction (PE/ICO/ICNS/.app/.desktop), window control, tray, single-instance lock, drag-and-drop routing and sounds.
Shells call only `Platform`, `Sounds` and `IconRegistry` — never `OS`/`DisplayServer` directly. See
[PLATFORM.md](PLATFORM.md) for behavior notes and the known differences from the Electron build.

## Startup
1. `ProgramStore.init_store()` loads and migrates the data file (recovering from a corrupt file via the newest backup).
2. `main.gd` configures the window for the stored shell (borderless for WfW, OS frame for Windows 95), resolves the
   integer scale, mounts the shell, starts the tray and single-instance listener.
3. The shell builds its UI from `ProgramStore.groups`/`settings` and listens for `groups_changed`/`settings_changed`.

## Shell switching
Settings are validated and persisted first (`ProgramStore.apply_settings_transaction`), then the host flips the frame,
re-resolves the scale, and mounts the other shell. Each shell keeps independent window geometry per group.

## Testing
* **Unit** (`tests/unit`, run by `tests/run_tests.gd`): ports of the original vitest suites plus tests for each new module.
* **Visual** (`tests/visual`): `--capture=<view>` runs the real app with a deterministic fixture profile, drives it with
  *injected input events* addressed by stable automation ids (`tests/visual/AUTOMATION_IDS.md`), saves a PNG, and
  `compare.py` applies the original rule (≤ 0.5 % of pixels differing by > 20/channel). The committed baselines are the
  renders of the Electron build.
