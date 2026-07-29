# Plan: Audit and complete Windows 3.1 Program Manager parity

## Context

The Win31 shell is intended to reproduce Windows 3.1 Program Manager, but the current repository needs a feature-by-feature and visual audit before more implementation. The requested first milestone is the Program Manager layout, with period-accurate chrome, menus, icons, controls, spacing, typography, and behavior rather than a merely retro-inspired approximation.

Confirmed requirements:
- The reference system is **Windows for Workgroups 3.11**.
- The layout must work at modern desktop resolutions rather than being limited to a 640×480 canvas.
- Launcher-only features must be hidden from the primary Program Manager interface.
- Icons must be recreated rather than copied from Microsoft resources. They should preserve the original 32×32 design, scale crisply at integer factors, and may add restrained detail in higher-resolution variants.
- The complete Win31 UI must scale proportionally by integer factors selected automatically from display resolution, with an in-app override.
- WfW 3.11 and Win95 must remain separate presentations; shared launcher data/operations may be reused underneath, but one shell’s UI decisions must not leak into the other.
- Seven supplied screenshots on the Desktop are the initial visual references. The two direct Program Manager references are `win311fw-1-1.png` (windowed with the Main group open) and `win311fw-1-1 (1).png` (maximized with all groups minimized); the other captures document the shared WfW 3.11 control language.
- First launch must retain an **empty user workspace**. The reference group names/items are comparison fixtures only and must not be seeded into user data.

Initial findings:
- The shell already has a custom outer caption, menu bar, MDI client, group windows, program items, dialogs, and Win31-scoped styles, but many pieces are approximations rather than reference matches.
- The current font is `W95FA`, a Windows 95-style bundled font, not a verified WfW 3.11 system/menu font.
- The reference Program Manager has only its caption, canonical `File / Options / Window / Help` menu bar, and MDI client—no toolbar. Toolbars shown in the supplied File Manager/WinPopup captures are application-specific and should not be added to Program Manager.
- The current File menu exposes `URL`, `Launch Groups`, `Import`, `Export`, and `Settings`; Help exposes Quick Search; the empty group view advertises drag/drop. These violate the requirement to hide launcher extensions from the primary Win31 UI.
- Canonical command labels exist, but several behaviors are not implemented faithfully: `Move...` opens item properties, `Copy...` immediately creates “Copy of …”, `Run...` opens the item editor, `Open` only handles selected items, and `New...` is a web-style hover submenu rather than the WfW New Program Object dialog.
- Minimized group icons are rendered by a flex bar, ignore stored `x/y`, cannot be selected or dragged, and `Arrange Icons` writes coordinates that the rendering does not use. The supplied reference instead places 32×25 group-window icons in free MDI space along the bottom.
- `Cascade` currently restores every minimized group and applies fixed 300×200 sizing; authentic window arrangement should preserve minimized groups and derive geometry from the live MDI client.
- Program-item layout uses responsive CSS grid, optional wrapping/ellipsis, right-click context menus, drag/drop highlighting, and modern empty-state text. The reference uses fixed logical icon cells, single selected label blocks, period keyboard semantics, and no modern instructional empty state.
- Generic assets in `icons.ts` mix Inkscape-generated PNGs with modern SVG symbols, rounded corners, antialiasing, and colors outside the WfW visual vocabulary; they are not faithful recreations of the supplied icon artwork.
- The app also has a Win95 shell; Win31 changes must remain scoped so Win95 does not regress.
- `PLAN.md` describes a previous fidelity pass as complete, so this task must verify actual code and captured output rather than relying on that checklist.

## Current parity gaps

### P0 — layout and visual system

- **Whole-shell scaling is absent.** `groupChromeScale` scales only group-caption variables by fractional values and writes global root variables used by both shells. There is no automatic integer scale, no full-shell scale override, and no logical-coordinate conversion for dragging/resizing.
- **WfW and Win95 layout state is shared.** Both shells read/write the same `ProgramGroup.windowState` and global MDI store, so position, size, minimized/maximized state, and titlebar scale leak between shells.
- **Visual components are also shared.** Win31 and Win95 both render `ItemGrid`, `ProgramItem`, common controls, dialogs, global variables, and global scrollbar/reset rules; editing these in place cannot guarantee that Win95 remains unchanged.
- **Typography is unverified and likely wrong.** All UI uses bundled `W95FA`; the supplied WfW captures use Windows 3.x system/menu bitmap metrics. Browser font smoothing and fallback behavior are not controlled consistently.
- **Chrome is approximate.** Frame bevel layers, caption/control geometry, menu baselines, client borders, child-frame thickness, scrollbars, focus rectangles, and spacing are hand-tuned CSS rather than derived from measured reference tokens.
- **Icons are not faithful.** The generic collection mixes Inkscape PNGs and modern SVGs with antialiasing, rounded geometry, and arbitrary colors. There are no 1×/2×/3× WfW variants, `srcset` selection, HD native-app icon extraction, or separate Win31/Win95 asset catalogs.
- **First-run chrome is obscured by an extension.** The empty workspace is intentional, but the non-period Welcome dialog prevents the requested clean initial Program Manager view and must move outside the canonical shell experience. Reference groups may be used in test fixtures only, never seeded into user data.

### P1 — Program Manager behavior

- **Object layout is not Program Manager layout.** Auto Arrange alphabetically mutates item data; WfW Auto Arrange reflows positions without renaming/reordering the object model. With Auto Arrange off, items still cannot be freely positioned or dragged because item coordinates are not stored.
- **Minimized groups are incomplete.** Their rendered flex positions ignore `windowState.x/y`; they cannot be selected, focused with period semantics, or dragged. `Arrange Icons` therefore has no visible effect despite writing coordinates.
- **Window arrangement is incorrect.** Cascade restores minimized groups and forces 300×200 geometry; Tile and Cascade do not reserve icon rows or reproduce WfW ordering. Group window state is not represented independently per shell.
- **Child-window controls are incomplete.** Clicking a child system button does nothing, there is no child system menu, titlebar double-click does not maximize/restore, keyboard Move/Size is absent, and outer system-menu Move/Size are permanently disabled.
- **Canonical File commands are placeholders.** `New...` is a custom submenu; `Open` only launches an item; `Move...` opens Properties; `Copy...` creates an immediate “Copy of”; `Run...` opens New Item; and Exit is labeled `Exit Program Manager` instead of the reference command. Group selection is not integrated with these commands.
- **Menu semantics are incomplete.** Alt/F10 menu mode, Alt+Space, child system-menu access, complete item mnemonics, active-window check marks in Window, robust submenu arrow navigation, and authentic pressed/check/disabled glyphs are missing or partial. Help Contents and How to Use Help are disabled.
- **Non-period interactions remain visible.** Win31 surfaces expose right-click context menus, drag/drop highlighting, URL creation, batch launch, import/export, Settings, Quick Search, progress toast, sounds/animations, dark mode, wrapping/ellipsis, and onboarding. These must not alter the canonical Program Manager surface.

### P2 — dialogs and application boundary

- **Canonical dialogs are missing.** There is no New Program Object chooser, Move Program Item, Copy Program Item, Run, or Change Icon dialog. Program Group/Item Properties do not match WfW field sets, button stacks, dimensions, mnemonics, or Help behavior.
- **Program Item metadata is incomplete for parity.** WfW-style shortcut key and Run Minimized behavior are absent, while launcher-only Program Group and Launch Group selectors are embedded in the canonical properties dialog.
- **Modal behavior is web-like.** Clicking the overlay closes dialogs; dialogs cannot be moved; their system menu is nonfunctional; controls use native HTML select/range behavior; and one shared dialog implementation is visually reused across shells.
- **App-level feature access is not separated.** Removing extensions from the Win31 menus would currently strand Settings, shell switching, import/export, URL creation, and batch configuration. The existing tray can launch items and exit but has no app-settings/tools entry point.
- **Automated visual verification is absent.** Existing tests cover utilities and IPC only; there is no component interaction harness, fixed-state screenshot fixture, pixel-diff baseline, or scale/migration coverage.

## Approach

1. Use the supplied WfW 3.11 Program Manager captures as the visual baseline and the related captures for shared controls, with additional references only for states not pictured.
2. Inventory every current Win31 surface and interaction, then compare it with the baseline at equivalent logical scale and at representative modern resolutions.
3. Produce a prioritized gap matrix distinguishing missing behavior, incorrect behavior, incorrect layout/chrome, non-authentic assets, and launcher extensions that must be removed from view.
4. Build the WfW shell in a 640×480 reference coordinate system, then apply a shell-owned integer UI scale. In Auto, choose the largest supported integer that fits the active display work area relative to the reference canvas (clamped to a practical maximum); expose `Auto / 1× / 2× / 3× / 4×` in app-level settings. Store all Win31 geometry in unscaled logical units and convert pointer/resizing coordinates at the shell boundary so changing scale does not move user objects.
5. Recreate icons as high-resolution masters plus explicit integer-scale outputs. Preserve the 32×32 composition at 1×; permit restrained extra detail only in larger variants, without changing the recognizable silhouette or palette.
6. Implement parity in layers: main frame/layout, canonical menus and MDI, group/item icons, then canonical dialogs/controls. Keep app-only capabilities out of the canonical Program Manager menus and workspace. Add a shell-neutral `Launcher Tools` entry point to the native tray for shell selection, UI-scale override, URL/batch metadata, import/export, theme/sound preferences, and onboarding; retain Quick Search as an undisplayed global shortcut.
7. Split shared visual primitives where necessary: Win31 gets its own item grid, controls, scroll areas, menus, and canonical dialogs; Win95 keeps its current rendered components. Keep Win31 assets, settings, and every non-reset CSS rule namespaced under `.shell-win31`, reusing only headless data/launch services.

## Files to modify

Expected critical paths (to be refined by the audit):
- Data migration and shell-specific settings/layout: `src/shared/types/index.ts`, `src/main/store.ts`, `src/main/ipc/storeHandlers.ts`, `src/renderer/src/store/programStore.ts`, `src/renderer/src/store/mdiStore.ts`
- Resolution/scale and app-level tools IPC: `src/main/window.ts`, `src/main/tray.ts`, `src/shared/constants/ipc.ts`, `src/preload/index.ts`, `src/renderer/src/types/electron.d.ts`
- `src/renderer/src/shells/Win31Shell.tsx`
- `src/renderer/src/styles/win31.css`
- `src/renderer/src/styles/variables.css`
- `src/renderer/src/styles/mdi.css`
- `src/renderer/src/styles/menu.css`
- `src/renderer/src/styles/dialog.css`
- `src/renderer/src/components/Menu/*`
- `src/renderer/src/components/MDI/*`
- New Win31-owned item, control, scrollbar, and canonical-dialog components; keep or relocate the current shared implementations as Win95/app-tool components rather than restyling them globally
- `src/renderer/src/components/Items/*`
- `src/renderer/src/components/Dialogs/*`
- `src/renderer/src/components/Common/*`
- New Win31-only asset catalog under `src/renderer/src/assets/` and replacement/refactor of `src/renderer/src/utils/icons.ts`
- Shell-neutral app-tools/settings surface plus Win31-specific canonical dialogs
- Main/preload window APIs only where authentic window behavior is currently impossible in the renderer
- Test fixtures/configuration for interaction and screenshot comparison

## Reuse

- Existing Win31 shell boundary: `.shell-win31` / `Win31Shell.tsx`
- Existing MDI state and commands: `src/renderer/src/store/mdiStore.ts`
- Existing program/group data and operations: `src/renderer/src/store/programStore.ts`; reuse CRUD/launch behavior but migrate visual state to shell-specific records.
- Existing menu primitives: `src/renderer/src/components/Menu/*`
- Existing window IPC: `src/main/ipc/windowHandlers.ts` and `src/preload/index.ts`
- Existing application-icon extraction/lookup should be retained where it supplies the real target program icon, extended to request suitable high-resolution sources; generic embedded icons require replacement.
- Existing tray boundary in `src/main/tray.ts` is the preferred shell-neutral entry point for hidden launcher tools.
- Existing schema defaults/merge in `src/shared/types/index.ts` and `programStore.loadData()` can host backward-compatible migration rather than invalidating saved workspaces.

## Steps

- [x] **Confirm target and complete the static gap audit.** Lock the target to WfW 3.11, modern integer scaling, recreated HD assets, an empty first-run workspace, hidden launcher extensions, and strict Win31/Win95 presentation separation. Use the gap matrix above as the acceptance backlog.
- [x] **Create measured WfW design tokens and fixtures.** Measure the supplied frame, caption, menus, child window, minimized groups, labels, and palette in logical pixels; add reference-state fixtures containing the pictured groups/items without writing them to user storage. Replace `W95FA` in Win31 with a licensed/recreated Windows 3.x-metric bitmap face and document its provenance. Do not add a Program Manager toolbar.
- [x] **Separate shell state with backward-compatible migration.** Version persisted data; migrate the single `windowState` into independent Win31 and Win95 position/size/minimize/maximize records, add Win31 logical item/group-icon positions, and add Win31 `Auto | 1× | 2× | 3× | 4×` scale preference. Preserve existing groups/items and map old geometry to both shells once. Stop Auto Arrange from alphabetically mutating item order.
- [x] **Implement the integer-scale foundation.** Resolve Auto from the active display’s effective work area against the 640×480 reference canvas, clamp to supported factors, and expose display changes to the renderer. Render Win31 from unscaled logical coordinates, convert drag/resize pointer deltas at one shell boundary, constrain windows/icons in logical space, and keep all scale variables/classes under `.shell-win31`; remove the shared fractional titlebar mutation.
- [x] **Rebuild the outer Program Manager frame.** Match measured frame/bevel layers, active/inactive caption, centered title, system button, down/up caption controls, menu/client boundaries, cursor behavior, and blank white MDI client. Keep the frameless Electron window, synchronize focus/maximize state from main-process events, and implement outer Restore/Move/Size/Minimize/Maximize/Close behavior—including Alt+Space and keyboard Move/Size—without host-native chrome leaking through.
- [x] **Replace the menu model with canonical WfW commands.** Render only `File / Options / Window / Help` with reference spacing and glyphs. Implement New, Open, Move, Copy, Delete, Properties, Run, Exit Windows, Auto Arrange, Minimize on Use, Save Settings on Exit, Cascade, Tile, Arrange Icons, group-window list/check state, Contents, Search for Help On, How to Use Help, and About. Add Alt/F10 menu mode, mnemonics, arrow traversal, Escape, pressed/disabled/checked states, and child/outer system-menu keyboard access. Remove URL, batch, import/export, app Settings, and Quick Search from these menus.
- [x] **Complete the MDI window manager.** Add a Win31 selection model for program items and minimized groups; implement child system menus, titlebar double-click, activation/z-order, logical dragging/resizing, maximize/restore geometry, close-to-icon behavior, and custom period scrollbars. Make Cascade/Tile operate only on restorable windows, preserve minimized groups, reserve bottom icon rows, and calculate arrangement from the live logical client. Render minimized groups at stored freeform positions, allow selection/drag/restore, and make Arrange Icons visibly pack them along the bottom as in the reference.
- [x] **Implement authentic program-item layout in Win31-owned components.** Store manual logical positions when Auto Arrange is off; when enabled, reflow in stable item order using measured fixed cells rather than a responsive CSS grid or alphabetical sort. Match 32×32 icon placement, label baseline, selected-label rectangle, dotted focus, clipping, double-click/Enter launch, and keyboard traversal. Remove Win31 context menus, hover washes, instructional empty text, visible drag/drop decoration, wrapping/ellipsis controls, and web-style animations while retaining nonvisual launch behavior; leave Win95’s current `ItemGrid` behavior and rendering intact.
- [x] **Recreate and isolate the WfW asset catalog.** Replace generic Win31 SVG/PNG approximations with original redraws for Program Manager, program/group/default/dialog symbols, caption/menu/scrollbar glyphs, and the period icon-picker set. Supply explicit 32/64/96/128 variants (or equivalent deterministic outputs), preserve the 1× silhouette and 16-color palette, select variants for integer scale/DPR, and use the best available high-resolution source for extracted host-application icons. Keep Win95’s existing icon catalog and rendering path untouched.
- [x] **Implement Win31-owned canonical dialogs and metadata.** Route dialogs by active shell instead of restyling the shared dialog tree. Add New Program Object, Program Group Properties, Program Item Properties, Move Program Item, Copy Program Item, Run, Change Icon, confirmation/Exit Windows, Help, and About compositions with measured controls, mnemonics, default/focus behavior, draggable modal frames, and non-dismissible backdrops. Restore WfW-equivalent shortcut-key and Run Minimized metadata/behavior where the host supports it. Remove Program Group and Launch Group extension fields from canonical item properties and replace native HTML-looking selects/ranges with Win31-owned controls where needed; preserve Win95’s current dialogs.
- [x] **Move extensions to a separate application surface.** Add a tray `Launcher Tools` entry that opens a distinct native utility window/surface for shell switching, scale override, URL and batch metadata, launch groups, import/export, theme/sound options, and optional onboarding. Route Quick Search and batch feedback outside the canonical Win31 workspace. Keep the first Win31 launch blank with no seeded groups or automatic Welcome dialog; leave Win95’s existing extension access and visuals unchanged.
- [x] **Add regression and visual coverage.** Extend store/IPC tests for schema migration, scale validation/display selection, shell-specific geometry, canonical command state, stable Auto Arrange, Move/Copy, and tray-tools routing. Add an Electron interaction/screenshot harness with deterministic reference fixtures and separate Win31/Win95 baselines.

## Verification

- At 1×, capture the windowed Program Manager/Main-group fixture and the maximized/all-groups-minimized fixture; overlay them on `win311fw-1-1.png` and `win311fw-1-1 (1).png` at matching logical dimensions. Check frame edges, title/menu baselines, child geometry, icon cells, labels, palette, and every control state—not just overall resemblance.
- Verify Auto chooses 1×/2×/3×/4× at representative effective work areas (for example 1366×768, 1920×1080, 2560×1440, and 3840×2160 within the fitting/clamp rule), then force each override. Resize/move/arrange at every factor and confirm saved logical geometry is unchanged when scale changes.
- Exercise mouse and keyboard paths for outer and child system menus, Alt/F10/mnemonics, all canonical menus, selected item versus selected minimized group commands, Move/Copy/Run, double-click/Enter, minimize/restore/maximize, manual item placement, Auto Arrange, Cascade, Tile, Arrange Icons, scrollbars, dialogs, and Help.
- Verify every recreated icon against the supplied silhouette, palette, internal geometry, label baseline, and selected state at 1× and supported integer scales. Confirm variant selection is crisp on standard and HiDPI displays and that host-extracted icons use the best available source without smoothing artifacts.
- Start from an empty store: the Win31 client must remain empty and unobscured. From the tray, verify Launcher Tools can still switch shells/scales, configure URLs and batch groups, import/export, search, and launch without adding extension commands or overlays to Program Manager.
- Import a pre-migration backup and switch repeatedly between Win31 and Win95. Groups/items must remain shared, while each shell retains independent geometry, minimized/maximized state, scale, components, assets, and styles.
- Run `npm run typecheck`, `npm test`, `npm run build`, and the new visual/interaction test command; package-smoke-test Windows because custom frameless movement, scaling, and focus behavior are platform-sensitive.
- Capture Win95 before implementation and compare afterward at the same data, window size, and state. Its native frame, desktop, taskbar, Start menu, windows, dialogs, icons, and interactions must remain visually unchanged.
