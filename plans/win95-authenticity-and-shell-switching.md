# Plan: Windows 95 fidelity and shell switching

## Context

The Windows for Workgroups 3.11 implementation must remain untouched. The Windows 95 shell should be rebuilt from its current retro approximation into a period-faithful **Windows 95 RTM retail** desktop, including authentic icons, visual metrics, interactions, and a clear way to switch in either direction between Windows 95 and Windows 3.11.

Confirmed requirements:
- Windows 95 **RTM retail** is the visual and behavioral reference—not OSR2, Internet Explorer shell updates, Plus!, Windows 98, or a generalized retro theme.
- Fidelity covers the launcher experience: desktop, Start menu, taskbar, launcher/group windows, app icons, launcher dialogs, and related mouse/keyboard/window behavior. It does not require emulating the operating system, filesystem, networking, Control Panel applets, Recycle Bin storage, or unrelated Windows applications.
- The Windows 95 shell remains inside the current **resizable, native-framed Electron window**; the host frame is outside the emulated desktop.
- Like the existing Win31 shell, Win95 must support crisp whole-shell integer scaling on higher-resolution displays. Add an independent `Auto / 1× / 2× / 3× / 4×` Win95 scale preference; Auto chooses the largest factor that fits a 640×480 logical desktop in the current inner viewport and updates at integer thresholds as the native host is resized or moved between displays.
- Built-in Win95 icons and fonts must be clean-room recreations that visually match RTM; no Microsoft binaries/resources will be copied. Asset provenance and redistribution terms must be documented.
- The primary launch path is the canonical hierarchy **Start → Programs → user group → app**. Bidirectional shell switching remains in the shell-neutral tray/Launcher Tools flow, with `Launcher Tools...` also available from the Windows 95 Start menu.
- Win31 implementation files, assets, styles, behavior, and baselines must not be changed.

Initial findings:
- The shells already have separate top-level components and `.shell-win95` / `.shell-win31` roots, and persisted group geometry is already separated by shell.
- Shell selection already exists in `LauncherTools`, persists through `AppSettings.shell`, and calls `window.recreateForShell`, but it is not directly discoverable from either historical shell.
- The current Win95 desktop has three hard-coded icons whose actions are placeholders: My Computer opens Settings, Network Neighborhood opens Quick Search, and Recycle Bin opens About.
- The Start menu shape is present, but includes app-specific commands and simplified hover-only behavior; Run opens the item editor, Help opens About, and Shut Down exits immediately.
- Group windows are a simplified Explorer-like composition. Their menu/toolbar controls are mostly inert, title-bar right-click opens group properties rather than a system menu, title-bar double-click and keyboard system-menu behavior are absent, and maximize/restore geometry is approximate.
- Current Win95 visuals use a generic shared icon catalog and shared item/dialog components. The generic catalog is mostly antialiased SVG artwork on colored square backgrounds rather than Windows 95 pixel icons. Shared item markup is still named/styled as Win31 and produces launcher instructions and context actions that do not match Explorer.
- The current RTM mismatches include gradient title bars, an IE-era address bar/Back toolbar composition, 16px top-level Start-menu icons, a branded `Gosh95` side strip, composited open/close animations, optional dark mode, and oversized 14px base typography. RTM should use its fixed classic palette, solid active/inactive captions, MS Sans Serif-compatible metrics, canonical `Windows 95` branding, and period state changes.
- Shared dialogs have Win31 markup with Win95 CSS overrides; overlay clicks dismiss them, title-bar controls/system menus are wrong for Win95, and multiple actions are placeholders. Win95 needs its own dialog frame and launcher-focused compositions.
- Drag/resize hooks can be reused, but `Win95Window` does not pass the desktop container to resize constraints and does not implement title-bar double-click or a system menu.
- The checked-in Win95 screenshot confirms major mismatches in icons, typography, spacing, taskbar/Start details, and dialogs. The visual script currently provides only one Win95 state and seeds no launcher items, so it cannot verify Start submenus or an Explorer window.
- Existing visual capture support already has a separate Win95 baseline and scenario.

## Approach

- Keep all implementation and styling changes inside Win95-owned components/assets/styles plus shell-neutral switching infrastructure; do not edit the Win31 shell, Win31 components, Win31 styles, WfW assets, or WfW visual baselines.
- Use a clean 640×480 Windows 95 RTM retail installation with default display appearance as the canonical 1× reference. Measure desktop/taskbar/Start menu/window/dialog metrics and encode them as unscaled Win95 logical-pixel tokens. Apply one shell-root integer transform, size the logical desktop to `viewport / scale`, and use nearest-neighbor assets so every control scales proportionally and crisply at 1×–4×. Keep the native Electron host frame unscaled.
- Create a Win95-owned scale provider, controls, item views, menu state, dialog routing, session window manager, and a clean-room bitmap-asset catalog matching RTM silhouettes and palette. Store Win95 window geometry in 1× logical units and convert pointer movement/resizing at the Win95 shell boundary so changing scale never moves or resizes saved objects. Stop Win95 from using the shared MDI store and `.win31-*` visual components; leave those paths unchanged for Win31.
- Replace placeholder interactions with period-appropriate desktop, Start menu, taskbar, window, menu, dialog, mouse, and keyboard behavior while preserving the launcher’s underlying group/item data and host launch operations. Canonical system entries that are outside launcher scope remain visually correct but are disabled or route to a concise launcher-specific explanation rather than pretending to emulate Windows.
- Remove post-RTM/modern presentation from the canonical shell: no caption gradients, IE address bar, dark theme, web animations, shortcut hint, launch toast, or modern instructional empty state.
- Keep bidirectional shell switching in Launcher Tools, opened from the native tray and `Ctrl+Alt+T`; add a Windows 95 Start-menu shortcut to Launcher Tools. Reuse the existing persisted `settings.shell` and `recreateForShell` transaction and verify that each shell’s independent layout state survives switching.

### Launcher-focused Windows 95 mapping

- **Desktop:** render the RTM default My Computer, Network Neighborhood, and Recycle Bin icons with authentic selection/focus/label behavior. My Computer opens a Win95-owned launcher browser containing the user’s program groups; Network Neighborhood and Recycle Bin retain correct icon/open/context behavior but show a small Win95-style “not available in this launcher” message rather than fake OS state.
- **Programs:** map user groups to the canonical Programs submenu and group items to nested program entries. Selecting an item launches it; the current launcher-specific `Open` and batch entries are removed from canonical menus.
- **Documents:** render the canonical entry and an authentic empty submenu; do not invent recent-document storage.
- **Settings:** retain canonical-looking non-emulated entries where useful and add `Launcher Tools...`, the explicit shell/settings escape hatch approved for this project.
- **Find:** replace the generic Quick Search overlay with a Win95 Find-style launcher dialog backed by the existing cross-group search and launch logic; preserve the global search accelerator.
- **Run:** implement a Win95 Run dialog that launches an entered executable/path/URL through the existing launch IPC without saving it as an item.
- **Help/About:** use Win95-owned launcher help/about dialogs, not the current Program Manager dialog.
- **Shut Down:** show an RTM-styled shutdown confirmation and quit only the launcher after confirmation.
- **Explorer/group windows:** My Computer lists launcher groups; group windows list launchable items. File/menu/context commands are limited to opening/launching and managing launcher groups/items—no filesystem or network emulation.

## Files to modify

Expected critical paths:
- Existing Win95 shell compositions: `src/renderer/src/shells/win95/Win95Shell.tsx`, `Win95Desktop.tsx`, `Win95Taskbar.tsx`, `Win95StartMenu.tsx`, `Win95Window.tsx`
- New Win95-owned modules under `src/renderer/src/shells/win95/` for RTM tokens, viewport-aware integer scale context/conversions, icon lookup, item/folder views, reusable menus, system menus, dialogs, a pure keyboard/menu reducer, and a session window store that can represent My Computer and group windows
- `src/renderer/src/styles/win95.css`, rewritten as strictly `.shell-win95`-scoped RTM styles rather than overrides of `.win31-*`
- New clean-room bitmap assets and provenance under `src/renderer/src/assets/win95/`, plus a Win95-owned MS Sans Serif-metric font under `src/renderer/src/assets/fonts/win95/`; the legacy `src/renderer/src/utils/icons.ts` remains for app tools/old IDs and external extracted icons
- `src/renderer/src/App.tsx` to leave the existing DialogManager/QuickSearch/launch-feedback rendering and period keyboard handling unchanged on the Win31 path, while Win95 owns its dialogs/Find inside `Win95Shell` and does not render the modern launch toast; `src/renderer/src/store/uiStore.ts` only if additional Win95 dialog payload discriminants are required
- `src/shared/types/index.ts`, `src/shared/storeMigration.ts`, and `src/main/ipc/storeHandlers.ts` to add, default, validate, migrate, and test an independent `win95Scale` preference without altering `win31Scale`
- `src/renderer/src/components/LauncherTools/LauncherTools.tsx` to expose Win95 `Auto / 1× / 2× / 3× / 4×` alongside the confirmed shell-switch flow and clearer immediate-switch status
- `src/main/window.ts` to choose a Win95 initial content size from the same 640×480 integer-fit rule (clamped to the active display work area) while retaining its native frame and resize behavior. Existing tray, recreation IPC, and preload APIs remain reusable without new channels.
- `scripts/capture-wfw.cjs`, `package.json`, new Win95-only pure logic tests, deterministic Win95 fixtures, and `tests/visual/baselines/win95-*.png`
- `README.md`, `docs/USER_GUIDE.md`, and `CHANGELOG.md`

## Reuse

- Shell registry and resolution: `src/renderer/src/shells/registry.ts`, `src/renderer/src/App.tsx`
- Persisted shell choice: `AppSettings.shell` and `useProgramStore.updateSettings` in `src/shared/types/index.ts` and `src/renderer/src/store/programStore.ts`
- Existing display/window-state APIs and shell recreation: `getDisplayWorkArea`, `WINDOW_DISPLAY_CHANGED`, `WINDOW_STATE_CHANGED`, and `window.electronAPI.window.recreateForShell`; `main/window.ts` already retains normal bounds and maximized state while changing shell framing.
- Shell-specific geometry: `ProgramGroup.shellWindowState.win95` and `getGroupWindowState(group, 'win95')`
- Existing Win95 shell boundaries: `Win95Shell`, `Win95Desktop`, `Win95StartMenu`, `Win95Taskbar`, and `Win95Window`; their internals can be replaced without crossing into `Win31Shell` or `shells/win31/*`.
- Headless group/item CRUD and launch behavior in `programStore.ts`, `launchHandlers.ts`, and `window.electronAPI.program.launch`; UI fields remain shared data even when Win95 presents them differently.
- External host-app icon extraction from `app.getInfo`; display extracted full-color icons directly while using the Win95 catalog for built-in/fallback/system icons.
- Existing cross-group scoring/launch behavior in `QuickSearchOverlay.tsx`, extracted to a headless utility for the Win95 Find dialog rather than duplicating semantics.
- Existing drag/resize hooks where their constraints fit, with the desktop container supplied for boundaries and Win95-owned title-bar/system-menu/normal-restore behavior layered on top. Keep `mdiStore.ts` for Win31 and move Win95 open/focus/z-order state to its own store.
- Existing visual capture script, extending its `win95` scenario into multiple deterministic RTM states rather than introducing an unrelated harness.
- WfW isolation patterns already demonstrated by `shells/win31/tokens.ts`, `Win31ScaleContext.tsx`, `iconCatalog.ts`, `referenceFixtures.ts`, and `assets/wfw/`; mirror the integer-scale architecture in Win95-owned code without editing or importing Win31 presentation modules.

## Steps

- [x] Confirm the target and shell boundary: RTM retail, launcher-related behavior only, resizable native-framed host, independent Auto/1×–4× whole-shell scaling for high resolutions, tray/Launcher Tools in both shells, and a Win95 Start shortcut.
- [x] Audit the current Win95 UI and behavior against a clean default RTM reference; record measured tokens and an acceptance matrix for desktop, icons, taskbar, Start menu, windows, menus, dialogs, and keyboard/mouse interaction.
- [x] Add and isolate the Win95 integer-scale foundation: persist/validate/migrate `win95Scale`, resolve Auto from the live inner viewport against 640×480, expose logical point/delta conversions, scale one Win95 root from the top-left, select matching bitmap/DPR variants, and initialize new Win95 native windows at a display-appropriate integer size. Render Win95-owned dialogs/Find from `Win95Shell`, suppress the modern launch toast there, move its open/focus/z-order model out of the shared MDI store, make App-level Enter/Delete/menu handling defer to the active shell, and keep all scale CSS/assets/selectors under `.shell-win95`. Snapshot Win31 before this split and require pixel-identical WfW captures afterward.
- [x] Rebuild the Win95 desktop at RTM logical-pixel metrics: fixed teal palette, canonical system icons/order, selection mask and dotted focus, label painting, background click and selection behavior, double-click/Enter opening, context menus, icon alignment, and desktop keyboard navigation. Derive available logical width/height from the scaled viewport so the desktop, taskbar, menus, and window constraints remain correct at every resolution and host size.
- [x] Rebuild the 28px RTM taskbar: Start button/logo geometry, separators, equal-width task buttons and pressed active state, task minimization/restoration, overflow behavior, notification area bevel, and locale-stable clock.
- [x] Rebuild the canonical Start hierarchy (`Programs / Documents / Settings / Find / Help / Run... / Shut Down...`) with RTM 32px top-level and 16px submenu assets, `Windows 95` side strip, delayed submenu switching, click-outside dismissal, disabled/empty states, mnemonics, Windows-key/Ctrl+Esc opening, arrows/Home/End/Enter/Escape traversal, and edge-aware submenu placement. Put `Launcher Tools...` under Settings; map groups/items only beneath Programs.
- [x] Rebuild Explorer-style launcher windows with RTM solid caption colors and exact bevel/control metrics; remove the post-RTM address bar and current inert Back/Up composition. Implement active/inactive state, z-order, title double-click, caption/system menus, menu mnemonics, constrained drag/8-edge resize, saved normal bounds, minimize/maximize/restore/close, Alt+Space, Alt+F4, and taskbar synchronization.
- [x] Add Win95-owned My Computer/group contents: large/small icon display needed by the reference, launcher item selection/keyboard navigation, double-click/Enter launch or folder open, period-correct empty folder, drag-in app creation, and Explorer-style context/property/delete confirmations. Do not reuse `.win31-item-grid` or `.win31-program-item`.
- [x] Add a Win95-owned modal frame, buttons, inputs, checkboxes, list controls, menus, and launcher dialogs. Implement launcher-scoped Find, Run, item/group properties, add program/URL, Help/About, unavailable-system-feature notice, delete confirmation, and Shut Down; enforce Win95 focus/default-button/Escape/Alt+F4 behavior and do not close modals by clicking the backdrop.
- [x] Add clean-room RTM recreations for the MS Sans Serif-metric UI font and bitmap desktop icons, Start/menu commands, window/task glyphs, folders/default applications, dialog symbols, and empty/full states. Provide explicit 1×/2×/3×/4× variants (and account for device pixel ratio) that preserve the same logical pixel grid without browser smoothing. Document source measurements, authorship, and redistribution terms; add aliases for existing stored icon IDs and keep extracted application icons intact.
- [x] Remove Win95-only approximation leaks: first-run Program Manager welcome, shortcut hint, dark palette and fractional titlebar scaling, caption gradient, compositor animations, synthetic menu/window click tones, launcher batch item/toast in Start, modern empty instructions, and noncanonical hover/pressed effects. Retain sound settings for shell-neutral tools, but do not claim or copy Microsoft’s original audio.
- [x] Harden the persistent, bidirectional Win95/WfW 3.11 switch transaction in Launcher Tools: persist the complete settings payload, recreate once, preserve prior bounds/maximized state, indicate the active shell, and handle errors without leaving store/UI disagreement. Keep the tray and `Ctrl+Alt+T` routes available from both shells and the Start-menu route from Win95.
- [x] Add pure tests for Win95 scale validation/migration and Auto thresholds, logical pointer/geometry conversion, Start/menu keyboard reducers, icon aliases, search ranking, viewport/window constraints, taskbar button state, and shell-switch persistence/error handling. Extend the Electron harness with deterministic Win95 fixtures and scripted pointer/keyboard states at 1×–4×; replace/add only `win95-*` baselines.
- [x] Update user documentation for Win95 behavior and shell switching without changing the documented WfW behavior.

## Verification

- Compare deterministic 640×480 Win95 captures against clean Windows 95 RTM retail references at matching dimensions, including empty desktop, selected desktop icon, Start menu and each submenu tier, My Computer, a populated group window, active/inactive/restored/maximized windows, task-button states, context/system menus, Find/Run/properties/confirmation/Shut Down dialogs, and extracted/custom application icons.
- Exercise mouse and keyboard paths for desktop selection/opening, Start → Programs → group → app launch, delayed submenus, Windows key/Ctrl+Esc and mnemonic navigation, task switching/minimization, window management, context/system menus, drag-in creation, Find, Run, properties/delete, Help/unavailable notices, and confirmed/canceled Shut Down.
- Verify Auto selects 1×/2×/3×/4× at representative effective viewports/display work areas and changes only at integer-fit thresholds; test 640×480, 1280×960, 1920×1080, 2560×1440, and 3840×2160-class layouts plus manual host resizing and display moves. Force each override, then confirm the desktop fills the scaled logical viewport, taskbar remains pinned, menus stay onscreen, windows are constrained/recoverable, and controls/icons/fonts remain crisp and proportional.
- Drag, resize, maximize, minimize, restore, and arrange windows at every factor. Switch scales repeatedly and confirm persisted Win95 geometry remains unchanged in 1× logical units.
- Switch Win31 → Win95 → Win31 and Win95 → Win31 → Win95; confirm the setting persists, the host window recreates safely, data remains shared, and shell-specific group geometry/minimized/maximized records do not leak between shells.
- Run `npm run typecheck`, `npm test`, `npm run build`, and all Win95 visual scenarios. Re-run the existing WfW screenshots as regression checks and require no WfW baseline or behavior changes.
