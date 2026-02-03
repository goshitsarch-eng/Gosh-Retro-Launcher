# Codebase Health Audit Report

**Project**: Gosh-Retro-Launcher (Windows 3.1 Program Manager clone)
**Date**: 2026-02-02
**Auditor**: Automated analysis
**Scope**: Full codebase — 38+ source files across Electron main, preload, and React renderer

---

## Executive Summary

**Overall Health: Moderate — Functional but with notable gaps**

The codebase is well-structured with clean separation of concerns (main/preload/renderer), proper TypeScript typing, and good use of modern tooling (Electron 40, React 19, Zustand 5, Vite 7). The code compiles cleanly with zero TypeScript errors.

**Top 5 Concerns (ordered by impact):**

1. **Zero test coverage** — No test files exist anywhere in the project. Any refactoring or bugfix carries regression risk.
2. **Security: `sandbox: false`** — The preload script runs without sandbox, expanding the attack surface if the renderer is ever compromised (`src/main/window.ts:24`).
3. **Dead code paths** — Tray item launching sends an IPC event (`launch-item`) that no listener handles; `shortcutKey` field is stored/editable but never wired to any shortcut registration; `@electron-toolkit/utils` is a dependency but never imported.
4. **CI/CD broken** — All 5 GitHub Actions workflows reference `npm run package:*` scripts that don't exist in `package.json` (which has `build:*` instead).
5. **Unsafe type cast in store SET handler** — `storeHandlers.ts:56` casts `unknown` to `ProgramGroup[]` without validation, bypassing the validation that exists for imports.

---

## Detailed Findings

### 1. Static Analysis

**TypeScript**: Zero errors when `node_modules` are installed. Both `tsconfig.node.json` and `tsconfig.web.json` compile cleanly with `strict: true`.

**Observation**: `tsconfig.node.json` sets `"lib": ["ESNext"]` without `"DOM"`, which is correct for Node but means `console` and `setTimeout` are technically not in scope. This works at runtime because electron-vite polyfills these, but `tsc --noEmit` against `tsconfig.node.json` fails without `node_modules` due to missing type declarations. The `skipLibCheck: true` flag masks any issues in dependency types.

**No linter configured** — No ESLint, Prettier, or other linting tooling is present. Code style is consistent but enforced only by convention.

### 2. Dependency Health

| Issue | Details | Severity |
|-------|---------|----------|
| **Moderate vulnerability** | Electron <35.7.5 has ASAR integrity bypass (GHSA-vmqv-hx8q-j7mg). Current: ^40.0.0, but `npm audit` still flags it — likely a transitive issue or stale advisory. | Medium |
| **Unused dependency** | `@electron-toolkit/utils` (^3.0.0) is in `dependencies` but never imported in any source file. | Low |
| **Outdated packages** | `electron-store` 8.x (latest: 11.x), `uuid` 11.x (latest: 13.x). Neither is critical but electron-store 11 has ESM support. | Low |
| **react/react-dom in devDependencies** | These are runtime dependencies but listed under `devDependencies`. Works because electron-vite bundles them, but semantically incorrect. | Low |

### 3. Code Quality Patterns

#### Dead Code / Unfinished Features

| Location | Issue |
|----------|-------|
| `src/main/tray.ts:27` | Sends `launch-item` IPC event to renderer, but no listener exists in renderer code. The preload `validChannels` allowlist (`src/preload/index.ts:69`) only includes `QUICK_SEARCH_TOGGLE`. **Tray item launching is silently broken.** |
| `src/shared/types/index.ts:9` | `shortcutKey: string` field exists on `ProgramItem`, is editable in `ItemPropertiesDialog`, but no code anywhere registers keyboard shortcuts via `globalShortcut` or any other mechanism. |
| `package.json:23` | `@electron-toolkit/utils` in dependencies, zero imports across codebase. |
| `src/shared/types/index.ts:68-71` | `FileFilter` interface exported but never imported/used anywhere. |

#### Inconsistent Patterns

| Location | Issue |
|----------|-------|
| `package.json:17-18` | `typecheck:main` and `typecheck:preload` are identical commands (`tsc --noEmit -p tsconfig.node.json`). The preload is included in the node tsconfig, so this is redundant rather than wrong, but misleading. |
| `src/renderer/src/store/programStore.ts:104` | `updateGroupWindowState` only saves when `saveSettingsOnExit` is true, but other mutations (addGroup, deleteGroup, addItem, etc.) always save immediately. The `saveSettingsOnExit` setting only guards window position persistence, not "settings" as the name implies. |

### 4. Architecture & Design

**Strengths:**
- Clean 3-layer separation: main process, preload bridge, renderer
- IPC channels centralized in `src/shared/constants/ipc.ts`
- Shared types prevent drift between layers
- Preload uses `contextBridge` with channel allowlisting (though incomplete)
- Single-instance lock properly implemented

**Concerns:**

| Area | Issue | File(s) |
|------|-------|---------|
| **No error boundaries** | React renderer has no error boundary. An unhandled exception in any component will white-screen the entire app. | `src/renderer/src/main.tsx`, `src/renderer/src/App.tsx` |
| **Synchronous file I/O in main process** | `readFileSync` used in `launchHandlers.ts:67` (desktop file parsing) and `storeHandlers.ts:108` (import). Could block the main process on large files. | `src/main/ipc/launchHandlers.ts:67`, `src/main/ipc/storeHandlers.ts:108` |
| **Store write amplification** | Every mutation (add/update/delete group or item) triggers a full `store.set('groups', groups)` which serializes and writes the entire groups array to disk. With many groups/items, this could cause write contention. | `src/renderer/src/store/programStore.ts` |
| **No debouncing on window state saves** | `updateGroupWindowState` saves on every drag/resize movement when `saveSettingsOnExit` is true. No debounce. | `src/renderer/src/store/programStore.ts:97-107` |
| **Global shortcut conflicts** | `Ctrl+Shift+Space` is registered globally and may conflict with other apps (e.g., some IME switchers). No conflict detection or user configurability. | `src/main/index.ts:9-21` |

### 5. Error Handling & Edge Cases

| Location | Issue |
|----------|-------|
| `src/main/ipc/storeHandlers.ts:53-63` | STORE_SET handler casts `value as ProgramGroup[]` and `value as AppSettings` without validation. Contrast with STORE_IMPORT at line 116 which properly validates with `isValidGroup`. A malicious or buggy renderer could write arbitrary data to the store. |
| `src/main/ipc/launchHandlers.ts:143` | `programPath.toLowerCase().split('.').pop()` — if path has no extension, `pop()` returns the full lowercase path, not `undefined`. Not a crash bug but could match unexpected `ext` values. |
| `src/renderer/src/store/programStore.ts:37-48` | `loadData` catches errors and sets `isLoading: false` but doesn't surface the error to the UI. User sees an empty app with no indication of failure. |
| `src/main/store.ts:25-28` | `getStore()` throws if `initStore()` wasn't called. If store initialization fails (caught in `index.ts:31`), subsequent IPC calls will throw unhandled errors. |
| `src/main/tray.ts:76-88` | Tray icon fallback is good — gracefully handles missing icon files with a data URL fallback. This is well done. |

### 6. Security Surface

| Issue | Location | Risk |
|-------|----------|------|
| **`sandbox: false`** | `src/main/window.ts:24` | The preload runs unsandboxed. If an attacker can execute code in the renderer (e.g., via a loaded URL), they have broader access. `sandbox: true` is the Electron security recommendation. Changing this may require refactoring the preload to use `ipcRenderer` only (which it already does). |
| **`shell.openExternal` on arbitrary URLs** | `src/main/window.ts:43-46` | The window open handler calls `shell.openExternal(url)` on any URL the renderer tries to open. No URL validation or allowlisting. A crafted link could open `file://` or custom protocol URLs. |
| **`shell.openExternal` in launch handler** | `src/main/ipc/launchHandlers.ts:228-234` | `SYSTEM_OPEN_EXTERNAL` IPC accepts any URL string from the renderer. No validation beyond the renderer's own UI. |
| **Import JSON parsing** | `src/main/ipc/storeHandlers.ts:109` | `JSON.parse(content) as StoreData` — the structural validation afterward is good, but very large JSON files could cause memory issues. No size limit on imported files. |
| **exec path validation incomplete** | `src/main/ipc/launchHandlers.ts:53-58` | `isValidExecPath` checks for shell metacharacters in the command, but the path itself (not just the command name) could contain directory traversal. On Linux, the `spawnDetached` at line 189 receives `programPath` directly without validation. |

---

## Proposed Remediation Plan

### Quick Wins (Low risk, high confidence)

| # | Change | Rationale | Risk | Verification |
|---|--------|-----------|------|-------------|
| 1 | **Fix CI workflow scripts**: Change `package:win`/`package:mac`/`package:linux` to `build:win`/`build:mac`/`build:linux` in all 5 workflow YAML files | CI is currently broken for all platforms | None — just script name alignment | Run `act` locally or trigger workflow_dispatch |
| 2 | **Remove `@electron-toolkit/utils` from dependencies** | Unused dependency, adds to bundle/install size | None — not imported anywhere | `npm install` + `npm run build` |
| 3 | **Add `launch-item` to preload valid channels OR remove tray launch-item code** | Tray item launching is silently broken | Low — either wire it up or remove dead code | Manual test: click tray menu item, verify launch |
| 4 | **Add URL validation to `shell.openExternal` calls** | Prevent opening `file://`, `javascript:`, or other dangerous protocols | Low — just add protocol allowlist (`http:`, `https:`) | Test that HTTP links still open, `file://` does not |
| 5 | **Add validation to STORE_SET handler** | Parity with STORE_IMPORT validation; prevents corrupt data writes | Low — reuse existing `isValidGroup` | Existing app functionality should be unaffected |

### Requires Careful Refactoring

| # | Change | Rationale | Risk | Prerequisites |
|---|--------|-----------|------|---------------|
| 6 | **Enable `sandbox: true`** | Electron security best practice. The preload already uses only `contextBridge` + `ipcRenderer`, so it should be compatible. | Medium — some preload APIs may behave differently sandboxed | Test all IPC channels thoroughly after change |
| 7 | **Add React error boundary** | Prevent full-app white-screen on component errors | Low-Medium — need to design fallback UI | Write the boundary component + basic test |
| 8 | **Debounce `updateGroupWindowState` saves** | Prevents disk thrashing during window drag/resize | Low — just add a debounce timer | Verify positions still persist on app close |
| 9 | **Replace `readFileSync` with async alternatives** | Avoid blocking main process | Low — straightforward async refactor | Test .desktop parsing and import still work |
| 10 | **Add ESLint + Prettier** | Enforce consistent code style, catch common issues | Low — config-only, no code changes needed initially | Run linter, fix any auto-fixable issues |

### Needs Architectural Discussion

| # | Change | Rationale | Considerations |
|---|--------|-----------|----------------|
| 11 | **Wire up or remove `shortcutKey`** | Dead feature creates user confusion (editable but non-functional) | If wiring up: needs design for conflict handling, registration lifecycle, cross-platform differences |
| 12 | **Move react/react-dom to `dependencies`** | Semantically correct; matters for any tool that reads package.json | electron-vite bundles everything regardless, so functional impact is zero |
| 13 | **Upgrade `electron-store` to v11** | ESM support, newer API | Breaking changes in v9+ (constructor changes). Needs migration. |

### Monitor but Defer

| # | Issue | Why Defer |
|---|-------|-----------|
| 14 | Store write amplification | Not a problem at realistic scale (dozens of groups, hundreds of items). Only matters if the app is used with thousands of entries. |
| 15 | Global shortcut conflicts | Works for most users. Making it configurable adds significant complexity for an edge case. |
| 16 | Electron ASAR integrity bypass vulnerability | Moderate severity, requires local file system access to exploit. Not relevant for most desktop app threat models. |

---

## Test Coverage Gap

**Current state: Zero tests.** No test framework, no test files, no test scripts in package.json.

**Recommended test strategy (in priority order):**

1. **IPC handler tests** (highest value) — Mock Electron APIs, test `launchHandlers`, `storeHandlers`, `fileHandlers`. These are the most critical code paths.
2. **Store validation tests** — Test `isValidGroup`, `isValidItem`, `parseDesktopFile`, `tokenizeCommand`, `isValidExecPath` with edge cases.
3. **Zustand store tests** — Test `programStore` actions with mocked `window.electronAPI`.
4. **Component smoke tests** — React Testing Library for key components (Dialog, MDIWindow, QuickSearchOverlay).

**Prerequisite**: Install a test framework (Vitest recommended — already compatible with Vite).

---

## Open Questions

| Question | What Would Resolve It |
|----------|-----------------------|
| Is tray item launching intended to work? (`launch-item` IPC has no listener) | Author confirmation + fix |
| Is `shortcutKey` a planned feature or vestigial? | Author input |
| Should the app work with `sandbox: true`? Any known blockers? | Enable it and test all features |
| What's the intended behavior of `saveSettingsOnExit`? Currently only guards window position saves. | Author clarification on expected scope |
| Are the empty `assets/icons/` and `resources/` directories expected to be populated before release? | Author input on packaging requirements |
| Is `@electron-toolkit/utils` intended to be used for something? | Author input |
