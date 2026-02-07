# Documentation Review

Critical review of all documentation produced for the Gosh Retro Launcher project, cross-referenced against the actual codebase.

Reviewed on: 2026-02-06

---

## Documents Reviewed

| Task | Author | Deliverable | Lines |
|------|--------|-------------|-------|
| #1 | Alex | `README.md` | 306 |
| #1 | Alex | `docs/USER_GUIDE.md` | 507 |
| #2 | Jordan | `docs/API_REFERENCE.md` | 546 |
| #2 | Jordan | `docs/ARCHITECTURE.md` | 540 |
| #3 | Riley | `docs/diagrams/system-architecture.md` | 247 |
| #3 | Riley | `docs/diagrams/data-flow.md` | 237 |
| #3 | Riley | `docs/diagrams/data-model.md` | 357 |
| #3 | Riley | `docs/diagrams/sequence-diagrams.md` | 363 |
| #3 | Riley | `docs/diagrams/deployment.md` | 246 |
| #3 | Riley | `docs/diagrams/user-flows.md` | 265 |

---

## 1. Inaccuracies Found (with evidence)

### 1.1 IPC Channel Count -- Inconsistent Across Documents

**Actual count**: 20 channels in `src/shared/constants/ipc.ts:4-38`

| Document | Claimed Count | Line | Verdict |
|----------|--------------|------|---------|
| Alex `README.md` | 16 | 146 | WRONG |
| Riley `system-architecture.md` | 17 | 92 | WRONG |
| Jordan `API_REFERENCE.md` | 20 (table) | 31-52 | CORRECT |
| Jordan `ARCHITECTURE.md` | 20 (in research log) | 523 | CORRECT |

**Evidence**: `src/shared/constants/ipc.ts` defines exactly 20 constants: WINDOW_MINIMIZE, WINDOW_MAXIMIZE, WINDOW_CLOSE, WINDOW_QUIT, WINDOW_IS_MAXIMIZED (5), FILE_SELECT_EXECUTABLE, FILE_SELECT_ICON, FILE_EXISTS (3), PROGRAM_LAUNCH, PROGRAM_LAUNCH_BATCH (2), STORE_GET, STORE_SET, STORE_GET_ALL, STORE_IMPORT, STORE_EXPORT (5), SYSTEM_GET_PLATFORM, SYSTEM_GET_VERSION, SYSTEM_OPEN_EXTERNAL (3), QUICK_SEARCH_TOGGLE (1), APP_GET_INFO (1).

Alex's "16 channels" appears to be an older count that omits some system and app info channels. Riley's "17 channels" is also stale.

### 1.2 Built-in Icon Count -- Inconsistent Across Documents

**Actual count**: 80 entries in `BUILTIN_ICONS` array at `src/renderer/src/utils/icons.ts:617-699`

| Document | Claimed Count | Line | Verdict |
|----------|--------------|------|---------|
| Alex `README.md` | 82 | 138, 301 | WRONG |
| Alex `README.md` | 80+ | 24 | ACCEPTABLE (hedged) |
| Alex `USER_GUIDE.md` | 80+ | 171, 183 | ACCEPTABLE (hedged) |
| Jordan `ARCHITECTURE.md` | -- | -- | Not stated |

**Evidence**: Counted via `grep -c "{ id:" src/renderer/src/utils/icons.ts` = 80. The `BUILTIN_ICONS` array spans lines 617-699 with exactly 80 `{ id: ... }` entries.

Alex's README line 138 ("82 built-in icon data URLs") and line 301 ("82 entries in BUILTIN_ICONS array") are incorrect. The hedged "80+" phrasing elsewhere is acceptable but imprecise.

### 1.3 Dialog Component Count in Riley's Diagram

**Riley's `system-architecture.md` line 65**: `Dialogs["Dialogs/<br/>DialogManager + 9 dialog components"]`

**Actual count**: 10 dialog types defined in `src/renderer/src/store/uiStore.ts:4-15` (newGroup, renameGroup, groupProperties, newItem, newUrl, itemProperties, settings, about, confirm, welcome). Plus the ThemePreview component is rendered inside SettingsDialog but is not a standalone dialog.

Jordan correctly states 10 dialog types at `ARCHITECTURE.md:233` and `API_REFERENCE.md` does not count them.

**Verdict**: Riley's "9 dialog components" is WRONG -- should be 10.

### 1.4 Startup Sequence Step Count

**Jordan `ARCHITECTURE.md` line 110**: "initializes in this exact order (verified from `app.whenReady()` callback at line 32)" then lists 6 steps.

**Actual code** at `src/main/index.ts:32-53`: The `app.whenReady()` callback performs 6 operations (Menu.setApplicationMenu, initStore, registerIpcHandlers, createWindow, createTray, registerGlobalShortcuts).

Jordan's numbered list shows 6 steps but the research log at line 511 says "5 steps". This is a minor internal inconsistency within Jordan's own document.

### 1.5 Store Module Export Count

**Jordan `ARCHITECTURE.md` line 157**: "Exposes six functions: `initStore`, `getGroups`, `setGroups`, `getSettings`, `setSettings`, `getAllData`, `setAllData`, `clearStore`."

That sentence says "six functions" but then lists eight. Minor copy-editing error.

---

## 2. Claims That Could Not Be Independently Verified

### 2.1 DevTools Environment Variable

Alex's README line 77 and USER_GUIDE line 454 claim that `ELECTRON_OPEN_DEVTOOLS=1` opens DevTools. Jordan's ARCHITECTURE line 143 says the same.

I did not read `src/main/window.ts` in full to verify the exact environment variable check. The claim is plausible given Electron conventions, and all three authors agree, but I could not independently confirm the exact variable name from the files I read.

### 2.2 BrowserWindow Minimum Size

Jordan `ARCHITECTURE.md` line 134: "minimum: 400x300". I did not read `src/main/window.ts` to verify the `minWidth`/`minHeight` values.

### 2.3 Tray Fallback Icon

Alex and Jordan both describe a fallback base64 PNG generated at runtime when tray icon assets are missing. I did not read `src/main/tray.ts` to verify this behavior.

### 2.4 File Handler Platform-Specific Filters

Jordan's API_REFERENCE lines 131-137 list platform-specific file dialog filters (Windows: .exe, .bat, .cmd, .msi; macOS: .app; Linux: .desktop, .sh). I did not read `src/main/ipc/fileHandlers.ts` to verify these exact lists.

---

## 3. Missing Platform Coverage

### 3.1 macOS-Specific Behaviors

All documents note macOS builds lack CI. Alex and Jordan mention macOS appropriately in launch behavior and tray differences. Riley's deployment diagram correctly shows macOS packaging config without a CI workflow.

However, none of the documents discuss:
- Whether macOS universal builds actually work (the electron-builder config specifies `arch: universal` but no CI validates this)
- Whether the macOS code signing identity and notarization settings in `electron-builder.yml` are functional (the `notarize: true` config was changed in commit `af838e8`)

### 3.2 ARM64 Linux Specifics

The CI workflow uses a separate `ubuntu-24.04-arm` runner for ARM64. Alex's README correctly documents this. However, commit `d7f5779` dropped ARM64 RPM from CI due to build failures, but `.rpm` is still listed as an output in the CI documentation. The Linux CI workflow may not produce ARM64 RPMs.

---

## 4. Diagram/Text Mismatches

### 4.1 IPC Channel Count (Riley vs Jordan)

As documented in Section 1.1:
- Riley's `system-architecture.md` line 92 says "17 channels"
- Jordan's `API_REFERENCE.md` correctly lists 20 channels
- The actual code has 20 channels

### 4.2 Dialog Count (Riley vs Jordan)

As documented in Section 1.3:
- Riley says "9 dialog components" in the system architecture diagram
- Jordan says 10 dialog types

### 4.3 Riley's Diagrams vs Jordan's Architecture -- Consistency Check

The following were verified as consistent between Riley's diagrams and Jordan's text:

- Shell system architecture: Both correctly show `registry.ts` with `Map<ShellType, ShellDefinition>`, two shells (Win31, Win95), and `App.tsx` resolving via `getShell()`.
- Zustand store shapes: Riley's data-model diagrams match Jordan's architecture descriptions for all three stores (programStore, uiStore, mdiStore).
- IPC handler registration order: Both show the same 5 handler modules registered in the same order.
- Security boundaries: Riley's security diagram and Jordan's security section both correctly describe contextIsolation, sandbox, event whitelist, and validation functions.
- Quick search scoring: Riley's data-flow diagram (prefix=3, substring=2, path/group=1) matches Jordan's architecture and the actual code at `QuickSearchOverlay.tsx:40-50`.
- Debounced save pattern: Both correctly describe 300ms debounce with two independent timers.

### 4.4 Riley's Diagrams vs Alex's User Guide

- Keyboard shortcuts: Riley's user-flows correctly show Alt+F/O/W/H and Shift+F4/F5 in Win31 shell, matching Alex's keyboard shortcuts table.
- Settings dialog structure: Riley's settings flow correctly shows the three sections (General, Appearance, Batch Launch) that Alex documents.
- Quick search behavior: Riley's quick search flow matches Alex's description of the feature.

---

## 5. Sections Most Likely to Go Stale (and Why)

### 5.1 HIGH RISK: Icon Count and List

**Files**: README.md line 138, USER_GUIDE.md line 171
**Why**: The icon count (currently 80) changes every time someone adds or removes icons from `src/renderer/src/utils/icons.ts`. The README already has a stale count of "82". Any commit touching `icons.ts` will make these numbers wrong.
**Recommendation**: Use "80+" or "over 75" hedging language, or remove the specific count entirely.

### 5.2 HIGH RISK: IPC Channel Count

**Files**: README.md line 146, system-architecture.md line 92
**Why**: Adding any new IPC channel to `src/shared/constants/ipc.ts` will make every hardcoded count wrong. Already stale in 2 of 4 documents.
**Recommendation**: Remove specific channel counts from narrative text. The channel table in API_REFERENCE.md is the authoritative source.

### 5.3 HIGH RISK: Dependency Version Table

**Files**: README.md lines 209-220, ARCHITECTURE.md lines 470-490
**Why**: Any `npm update` or dependency bump changes these version numbers. They will drift with routine maintenance.
**Recommendation**: Keep one canonical version table (in ARCHITECTURE.md or README.md, not both) and reference package.json as the source of truth.

### 5.4 MEDIUM RISK: Test Count

**Files**: ARCHITECTURE.md line 445 ("57 tests across 3 test files")
**Why**: Adding any test changes this number. The "57 tests" was verified at time of writing but will drift.
**Recommendation**: Say "50+ tests" or remove the exact number.

### 5.5 MEDIUM RISK: Shell Type List

**Files**: Multiple locations across all documents
**Why**: Adding a third shell (e.g., 'winxp') requires updates in types, registry, storeHandlers validation, and every document that lists `'win31' | 'win95'`.
**Recommendation**: The "Adding a New Shell" section in ARCHITECTURE.md is good. Other documents should reference it rather than repeating the shell list.

### 5.6 LOW RISK: CI Workflow Details

**Files**: README.md lines 223-233, ARCHITECTURE.md lines 390-431, deployment.md
**Why**: CI workflows change less frequently but are detailed enough that small changes (e.g., runner version, new build step) will cause drift.
**Recommendation**: Keep CI details only in ARCHITECTURE.md and deployment.md. README can summarize.

---

## 6. Gaps Between Documentation and What's Built

### 6.1 ErrorBoundary Component

Alex's README (line 115) and Jordan's ARCHITECTURE (line 56) mention `ErrorBoundary.tsx` exists, but neither Alex's USER_GUIDE nor Jordan's API_REFERENCE explain what happens when it catches an error (what the user sees, how to recover). This is a user-facing behavior that the User Guide should cover.

### 6.2 Drag-and-Drop Between Groups (moveItem)

The `programStore` has a `moveItem(fromGroupId, toGroupId, itemId)` action (line 169 of programStore.ts). Neither Alex's USER_GUIDE nor Jordan's ARCHITECTURE explain whether drag-and-drop between group windows is supported in the UI, or whether `moveItem` is only used internally.

### 6.3 Launch Group Numbering and UI

Alex's USER_GUIDE mentions launch groups 1-8, and `src/renderer/src/utils/launchGroups.ts` provides options 0-8 (0 = None). However, how the "Launch All" menu item discovers and orders items across groups is not explained in any document. The actual behavior (items are gathered from all groups, filtered by non-zero launchGroup, sorted by group number, launched with delay) should be documented.

### 6.4 Tray Menu Rebuild Timing

Jordan's ARCHITECTURE correctly notes the tray menu rebuilds on group saves. However, neither document explains that individual item renames within a group that don't trigger a full groups save will NOT update the tray menu. Alex's README line 263 touches on this as a "Known Limitation" but the wording is unclear.

### 6.5 Sound Effect Details Not in User Guide

Alex's USER_GUIDE mentions sounds can be toggled but doesn't list what sounds play and when. The actual sounds (startup chime, window open/close, menu click, dialog open, error beep, button click) are documented in the README but not the User Guide's troubleshooting section.

### 6.6 Window Open Handler for External Links

Jordan's ARCHITECTURE line 141 mentions `setWindowOpenHandler` intercepting new window requests and validating protocols. Jordan's API_REFERENCE line 506 mentions it. However, this security behavior is not in Alex's README or USER_GUIDE at all.

---

## 7. Discrepancies Between Teammates' Findings

### 7.1 Icon Count: Alex vs Actual Code

Alex claims 82 built-in icons (README line 138, 301). Actual count is 80. Alex's research log at README line 301 says "82 entries in BUILTIN_ICONS array" -- this is incorrect. The BUILTIN_ICONS array at `icons.ts:617-699` contains exactly 80 entries.

### 7.2 IPC Channel Count: Alex vs Riley vs Jordan

- Alex (README line 146): 16 channels -- WRONG
- Riley (system-architecture.md line 92): 17 channels -- WRONG
- Jordan (API_REFERENCE.md table): 20 channels -- CORRECT

### 7.3 Dialog Count: Riley vs Jordan

- Riley (system-architecture.md line 65): 9 dialog components -- WRONG
- Jordan (ARCHITECTURE.md line 233): 10 dialog types -- CORRECT

### 7.4 Startup Step Count: Jordan Internal

- Jordan (ARCHITECTURE.md line 110): Lists 6 steps -- CORRECT
- Jordan (ARCHITECTURE.md research log line 511): Says "5 steps" -- WRONG (internal inconsistency)

### 7.5 Store Export Function Count: Jordan Internal

- Jordan (ARCHITECTURE.md line 157): Says "six functions" then lists 8 -- copy-editing error

### 7.6 License Field

Alex (README line 278) correctly identifies the discrepancy: `package.json` says `"license": "MIT"` but the actual `LICENSE` file is AGPL-3.0. No other teammate mentions this. This is an important discrepancy in the project itself that should be resolved (the package.json license field should be corrected to `"AGPL-3.0"`).

---

## 8. Recommendations (Ranked by Priority)

### P0 -- Must Fix Before Merge

1. **Fix IPC channel count in README.md** (line 146): Change "16 channels" to "20 channels", or remove the number and say "all IPC channel constants" to avoid future staleness.

2. **Fix IPC channel count in system-architecture.md** (line 92): Change "17 channels" to "20 channels".

3. **Fix icon count in README.md** (lines 138, 301): Change "82" to "80". Better yet, use "80+" hedging.

4. **Fix dialog count in system-architecture.md** (line 65): Change "9 dialog components" to "10 dialog components".

5. **Fix store function count in ARCHITECTURE.md** (line 157): Change "six functions" to "eight functions" to match the list that follows.

6. **Fix startup step count in ARCHITECTURE.md research log** (line 511): Change "5 steps" to "6 steps".

### P1 -- Should Fix

7. **Add ErrorBoundary behavior to USER_GUIDE.md**: Explain what the user sees when a crash is caught and how to recover.

8. **Clarify ARM64 RPM availability**: The Linux CI dropped ARM64 RPM in commit `d7f5779`. Documents should note that ARM64 RPM may not be available as a CI artifact.

9. **Add sound effect list to USER_GUIDE.md troubleshooting**: List all 7 sound effects and when they trigger.

10. **Document moveItem behavior**: Clarify in USER_GUIDE whether drag-and-drop between groups is a user-facing feature.

### P2 -- Nice to Have

11. **Consolidate version tables**: Keep dependency versions in one place (ARCHITECTURE.md) and reference from README to avoid double maintenance.

12. **Use hedged language for counts**: Replace exact numbers (icons, tests, channels) with approximate ranges or remove them.

13. **Add "external link security" to USER_GUIDE**: Document that the app validates URL protocols when opening external links.

14. **Resolve package.json license field**: The project itself has a discrepancy (`"MIT"` vs AGPL-3.0 LICENSE file). This is a code fix, not a docs fix, but Alex correctly identified it.

---

## Research Log

### Method

1. Read all 10 deliverable files in full
2. For each factual claim about counts, names, or behavior, verified against the actual source file
3. Cross-referenced every diagram in Riley's deliverables against Jordan's text descriptions
4. Cross-referenced Alex's user-facing descriptions against actual component behavior in source

### Files Read for Verification

| File | What Was Verified |
|------|-------------------|
| `src/shared/constants/ipc.ts` | Counted all 20 IPC channel constants -- contradicts Alex (16) and Riley (17) |
| `src/shared/types/index.ts` | All interfaces match across all documents. 10 AppSettings fields, 6 ProgramItem fields (launchGroup optional), ShellType union, defaults. |
| `src/preload/index.ts` | 6 namespaces (window, file, program, store, system, app) + on/off event system. Matches Jordan's API_REFERENCE exactly. |
| `src/main/index.ts` | 6-step startup in app.whenReady(), single instance lock, global shortcut (Ctrl/Cmd+Shift+Space), error handlers. Contradicts Jordan's "5 steps" in research log. |
| `src/main/ipc/index.ts` | 5 handler registration calls in order. Matches all documents. |
| `src/main/ipc/storeHandlers.ts` | 3 validation functions (isValidItem, isValidGroup, isValidSettings). shell and soundEnabled are optional for backward compat. Matches Jordan and Riley. |
| `src/main/ipc/launchHandlers.ts` | Platform-specific launch, tokenizeCommand, isValidExecPath, parseDesktopFile, URL handling. Matches all documents. |
| `src/renderer/src/App.tsx` | Shell resolution via getShell(), shared shortcuts (Enter, Delete), quick search IPC, welcome dialog on first run. Matches all documents. |
| `src/renderer/src/shells/registry.ts` | Map-based registry with registerShell/getShell/getAllShells, 2 built-in shells. Matches all documents. |
| `src/renderer/src/shells/Win31Shell.tsx` | Alt+F/O/W/H, Shift+F4/F5, Escape shortcuts. Matches Alex and Riley. |
| `src/renderer/src/shells/win95/Win95Shell.tsx` | Start menu, taskbar, Escape closes start menu. Matches all documents. |
| `src/renderer/src/store/programStore.ts` | All actions, 300ms debounce, two independent timers. Matches Jordan and Riley. |
| `src/renderer/src/store/uiStore.ts` | 10 DialogType values. Contradicts Riley's "9 dialog components". |
| `src/renderer/src/store/mdiStore.ts` | z-index management, CustomEvent dispatch for cascade/tile/arrange. Matches all documents. |
| `src/renderer/src/utils/icons.ts` | BUILTIN_ICONS array: 80 entries (lines 617-699). Contradicts Alex's "82". |
| `src/renderer/src/utils/sounds.ts` | 7 sound functions + SoundPlayer interface + createSoundPlayer factory. Matches Jordan. |
| `src/renderer/src/hooks/useSounds.ts` | Wraps createSoundPlayer with settings check. Matches Jordan. |
| `src/renderer/src/components/QuickSearch/QuickSearchOverlay.tsx` | Scoring: prefix=3, substring=2, path/group=1. Max 10 results. Matches all documents. |
| `package.json` | Version 1.0.4, license field "MIT" (contradicts AGPL-3.0 LICENSE file), all scripts and deps verified. |
| `LICENSE` | AGPL-3.0 (not MIT as package.json states). Alex correctly identified this. |

### Verification Statistics

| Category | Count |
|----------|-------|
| Claims verified as correct | ~120 |
| Inaccuracies found | 6 |
| Internal inconsistencies | 2 |
| Claims not independently verified | 4 |
| Gaps identified | 6 |
| Cross-document discrepancies | 6 |
