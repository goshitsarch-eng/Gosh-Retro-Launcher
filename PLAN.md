# Plan: Stabilize memory use and restore Windows 3.11 fidelity

## Context

The Electron/React launcher reportedly consumes increasing memory after remaining open, gives no visible pressed/launch animation when a file is launched, and differs visually from the supplied Windows 3.11 Program Manager references (`/Users/gosh/Desktop/2Windows 3.1.pdf` and `/Users/gosh/Desktop/Windows 3.1.pdf`).

Confirmed requirements:
- The slowdown occurs while the app is idle and resolves after quitting; no process-level memory measurements have yet been captured.
- The missing feedback is **File → Launch All**: the selected menu command should turn blue while activated and the menu should close immediately, rather than remaining visibly open under the stationary pointer while programs launch.
- Visual matching covers the full Windows 3.11 Program Manager experience, including dialogs and minimized group icons, as closely as practical.
- Win95 mode must remain available and visually unchanged for now.
- A frameless, custom-drawn Win31 outer frame is approved. Because Electron cannot toggle native framing in place, changing between Win31 and Win95 may recreate the BrowserWindow after settings are saved.

Investigation findings:
- The Win 3.1 UI is primarily implemented by `Win31Shell`, the MDI/item/menu/dialog components, and split CSS files. Win31 and Win95 share primitives and global variables, so fidelity changes must be scoped under `.shell-win31` (or use Win31-only primitives) to avoid changing Win95.
- File → “Launch Groups” (`MenuBar.tsx`) starts sounds and launch-feedback state before calling `closeMenu()`. The menu item only has a CSS `:hover` state and no explicit active state, so the pointer can leave it visually selected while the asynchronous batch begins. Closing the menu first and supporting pointer-down/keyboard selected state will make activation deterministic.
- The supplied references show the classic Program Manager frame and menus, gray MDI workspace, compact child-window chrome, grid-style minimized group icons with dark labels, pixel icons, and dense Win3.x dialogs. Current mismatches include the extra “Auto/Manual Arrange” caption text, teal desktop-like MDI area, modern/custom folder treatment for minimized groups, oversized spacing/type, hover effects and scale/fade animations, incomplete outer/window chrome, noncanonical File/Help menu organization, synthetic SVG icon styling, and generalized dialog layouts.
- There is no recurring Win31 JavaScript timer during normal idle. Listener effects generally remove their listeners. Remaining idle-resource suspects to measure are the never-suspended global `AudioContext` created by the startup chime, Electron process/native memory behavior, retained compositor layers/animation state, and hidden-window/tray lifecycle. The startup timeout and several delayed close callbacks also lack unmount cancellation and should be hardened if profiling confirms retention.
- Broad Zustand selectors in `MenuBar`, `ItemGrid`, and settings subscribe components to more state than needed, but they do not by themselves explain monotonic idle growth; selector narrowing can reduce unnecessary rendering as part of the confirmed performance fix.

## Approach

1. Profile a packaged/production build at startup and over a fixed idle interval using Electron process metrics plus renderer heap snapshots, both visible and hidden-to-tray, to separate expected Chromium allocation from renderer heap retention, native/compositor growth, and CPU wakeups.
2. Fix only demonstrated lifecycle/resource problems. The first targeted checks are audio-context suspension/closure after scheduled tones, stale timeout cancellation, compositor animation cleanup, listener counts, and window/tray destruction; also narrow broad Zustand subscriptions where they cause recurring renders.
3. Correct File → Launch Groups activation so the menu item owns explicit pointer/keyboard active state, the dropdown closes and paints closed before sound/progress/IPC work begins, and focus returns consistently. Keep batch execution in `launchGroupBuckets()` and do not leave selection driven solely by a stationary `:hover`.
4. Create the BrowserWindow with a native frame for Win95 and a frameless/resizable window for Win31. Add a draggable Win31 Program Manager caption with system icon, centered title, minimize/maximize/restore controls, and close behavior wired to the existing window IPC. When a shell change crosses frame modes, immediately persist settings and recreate the BrowserWindow rather than visually altering Win95.
5. Build a Win31-scoped visual system from the reference traits: canonical menu hierarchy with launcher-only commands integrated unobtrusively, gray MDI client, compact child-window chrome, minimized group-window glyphs, raster/pixel icon treatment, selection/focus behavior, typography, metrics, bevels, scrollbars, and dense dialog/control layouts. Remove web-like hover/scale/fade treatments from Win31 while leaving Win95 rules untouched.
6. Apply the system across every Win31 dialog and state, preserving current features (batch launch, URL items, import/export, settings, quick search) even where they have no original Program Manager equivalent. Recompose Program Group/Item Properties, creation, confirmation, About, Settings, Welcome, and URL dialogs around shared Win3.x field/button patterns rather than one generic spacious layout.

## Files to modify

Expected critical areas (memory-related files may narrow after profiling):
- Window framing/recreation: `src/main/window.ts`, `src/main/ipc/windowHandlers.ts`, `src/shared/constants/ipc.ts`, `src/preload/index.ts`, and `src/renderer/src/types/electron.d.ts`
- Shell/settings lifecycle: `src/renderer/src/App.tsx`, `src/renderer/src/shells/Win31Shell.tsx`, and `src/renderer/src/components/Dialogs/SettingsDialog.tsx`
- Launch/menu behavior: `src/renderer/src/components/Menu/{Menu,MenuBar,MenuItem}.tsx`, `src/renderer/src/store/uiStore.ts`, and `src/renderer/src/utils/launchGroups.ts`
- MDI/items: `src/renderer/src/components/MDI/*`, `src/renderer/src/components/Items/{ItemGrid,ProgramItem}.tsx`
- Dialogs/controls: `src/renderer/src/components/Dialogs/*` and, only where Win31-scoped behavior is needed, `src/renderer/src/components/Common/*`
- Resource cleanup: `src/renderer/src/utils/sounds.ts`, `src/renderer/src/hooks/*`, and timeout-owning components confirmed by profiling
- Styling: `src/renderer/src/styles/{variables,win31,mdi,menu,dialog,animations}.css`
- Tests: new focused renderer utility tests and main window/IPC tests alongside the existing suites

## Reuse

- Existing program launch IPC: `src/preload/index.ts` and `src/main/ipc/launchHandlers.ts`
- Existing transient launch feedback state pattern: `src/renderer/src/store/uiStore.ts`
- Existing reduced-motion handling and delayed-unmount cleanup pattern: `src/renderer/src/styles/animations.css` and `src/renderer/src/hooks/useAnimatedUnmount.ts`; retain it for Win95 but avoid non-period Win31 effects
- Existing Windows palette/design tokens: `src/renderer/src/styles/variables.css`, overridden within `.shell-win31` rather than changing Win95 defaults
- Existing launch bucketing/execution: `collectLaunchGroups()` and `launchGroupBuckets()` in `src/renderer/src/utils/launchGroups.ts`
- Existing shared controls and icon lookup where their behavior fits; add Win31-scoped variants rather than globally restyling controls used by Win95
- Supplied single-page reference captures, rendered locally for detailed comparison, especially their Program Manager, Program Group Properties, About, Setup, PIF Editor, and system-dialog examples

## Steps

- [x] **Baseline idle behavior.** Record Electron main/renderer/GPU process memory and CPU at startup, after a five-minute warm-up, and through at least 30 minutes idle with the Win31 window visible; repeat hidden-to-tray. Take renderer heap snapshots and compare listener counts, DOM nodes, timers, audio state, and retained objects so expected Chromium caching is not mislabeled as a leak.
- [x] **Repair confirmed resource lifecycles.** Make Web Audio nodes disconnect when tones end and suspend the lazily created context after the last scheduled sound; cancel/reschedule the suspension safely for overlapping tones. Cancel startup/close timers on unmount, clear pending animation frames and transient compositor hints, and fix any additional retention path shown by the baseline. Narrow whole-store Zustand subscriptions that profiling shows causing avoidable redraws.
- [x] **Make Launch Groups activation deterministic.** Add explicit active/selected state and keyboard semantics to Win31 menu items, close the File dropdown first, allow that state change to paint, then begin sound, progress feedback, and existing batch IPC. Preserve launch order/delay, exactly-once execution, failure reporting, and optional minimize-on-use.
- [x] **Implement shell-aware outer framing.** Select native versus frameless BrowserWindow creation from the persisted shell, build the approved draggable Win31 outer caption/controls, and add a validated IPC path that saves shell settings before recreating the window when frame mode changes. Preserve bounds where possible, tray behavior, external-link protections, and all current Win95 native-frame behavior.
- [x] **Rebuild Win31 shell and menu fidelity.** Remove the non-period caption status, use compact Win3.x metrics and centered caption/title text, convert the MDI workspace from teal desktop treatment to the reference gray client area, implement canonical File/Options/Window/Help ordering and keyboard navigation, and place app-only actions without removing functionality.
- [x] **Rebuild MDI and item states.** Match child-frame bevels, active/inactive captions, Win3.x control glyphs, maximize/restore/minimize behavior, resize edges, stacking, cascade/tile, scrollbars, icon grid density, label selection rectangles, focus dotted lines, and no web-style hover wash. Render minimized groups as the reference group-window glyph plus dark label and arrange them along the client bottom.
- [x] **Normalize Win31 icons.** Keep extracted application icons, but replace conspicuously modern flat SVG/default/group symbols with palette-limited pixel assets or CSS glyphs appropriate to Win3.x; enforce integer 16/32px rendering and avoid changing Win95 icon presentation.
- [x] **Recompose all Win31 dialogs and overlays.** Apply compact title bars, etched groups, aligned labels/fields, right-side or bottom button stacks matching the relevant reference, default/focus outlines, disabled states, icon chooser, About composition, and Win3.x-styled custom surfaces for Settings, URL creation, Welcome, Quick Search, and launch progress.
- [x] **Add regression coverage.** Test launch grouping/order/progress, audio node cleanup and delayed context suspension with fake timers, shell-to-frame selection and window recreation validation, and any extracted menu state reducer/helper. Keep component interaction and visual states in the manual checklist where the current Node-only Vitest setup cannot render DOM components without adding a new test dependency.

## Verification

- Run `npm run typecheck`, `npm test`, and `npm run build`; package/smoke-test the relevant host build if signing credentials are available.
- Repeat the visible and hidden 30-minute memory profile. Renderer heap, listener/DOM counts, and audio resources must settle after warm-up with no monotonic retained-object growth; compare main/GPU working sets and idle CPU to baseline and investigate any continuing slope rather than relying on one Activity Monitor number.
- Leave sound enabled through startup and several UI sounds, then verify the AudioContext returns to suspended state and no oscillator/gain graph remains retained; repeat with sound disabled.
- Verify File → Launch Groups on pointer press/release, Enter, mnemonic, Escape, and outside-click paths. It must show the blue selected state, close before launch work, launch each configured item once in group order, honor delay/minimize settings, and show success or failure without reopening the menu.
- Verify Win31 native-window actions and shell switching on macOS plus at least one Windows/Linux package: drag, resize, minimize, maximize/restore, tray-close, quit, relaunch/recreation, preserved bounds, and native Win95 frame after switching back.
- Compare captured Win31 states against both supplied references at matched scale: outer frame; each menu and disabled/check/submenu state; active/inactive/maximized child windows; selected and focused program items; minimized groups and Arrange Icons; scrollbars; every dialog, icon chooser, Quick Search, empty/error/progress state, light/dark and scale options.
- Smoke-test Win95 before and after at the same dimensions. Its native frame, desktop, windows, Start menu, taskbar, icons, dialogs, launch flow, and keyboard shortcuts must remain visually and functionally unchanged apart from unavoidable shared bug fixes.
