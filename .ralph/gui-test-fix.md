# Full GUI Testing + Bugfix Loop — Win 3.11 (WFW) & Win 95 Shells

Exhaustively GUI-test both shells of the Gosh Retro Launcher (Electron + React), fix every bug found, and re-test until everything is fully green. Do NOT stop until all phases pass with zero failures.

Task file (source of truth, update each iteration): `.ralph/gui-test-fix.md`

## Phases
- Phase A: static health gate (typecheck, unit tests, build)
- Phase B: existing visual regression suites (wfw reference, wfw desktop, 39 win95 scenarios)
- Phase C: extended GUI exploration — capture screenshots of interactive scenarios for BOTH shells and visually inspect them with the read tool (menus, dialogs, window states, drag, scales, context menus, taskbar, find, run, shutdown, properties)
- Phase D: fix every bug found, log each in the task file Bug Log
- Phase E: full re-verification in one clean pass: `npm run typecheck && npm test && npm run test:visual` plus re-capture of every previously-buggy scenario

Rules: never update baselines to mask a regression; only update after visually confirming new render is correct. Record verification evidence per iteration. Final completion requires the full command green from a fresh shell.

## Checklist

### Phase A — Static health gate
- [x] A1. `npm run typecheck` passes (main + preload + renderer)
- [x] A2. `npm test` passes (129 tests, 22 files)
- [x] A3. `npm run build` succeeds

### Phase B — Existing visual regression suites
- [x] B1. wfw-reference: diff 4.126% = stale baseline (RTM icons commit 669dc0d), visually verified correct → baseline updated
- [x] B2. wfw-desktop: diff 2.299% stale → updated; wfw-desktop-minimized PASS (0.241%)
- [x] B3. Win95: all 39 reviewed visually; baselines refreshed after fixes; suite green 39/39 @ 0.000% (iter2)

### Phase C — Extended GUI exploration (capture + inspect)
Win 3.11 / WFW shell:
- [x] C1. Workspace, File/Options/Window/Help menus — all correct (checkmarks, group list, mnemonics)
- [x] C2. Dialogs: About, New Program Object, Run, Exit Windows, Item Properties, Group Properties, New Group, Move/Copy — all correct
- [x] C3. Group window: maximize (MDI), minimized icons, item selection (File Manager highlight) — correct
- [x] C4. Scales 1–4 (probe + captures), desktop mode, launcher tools window, shell switch win95→win31 — all correct
- [x] C-extra. win95 icon context menu, win95→win31 Shut Down switch flow — correct
Win 95 shell (via scenario review):
- [x] C5. Desktop icons/select/marquee basics (desktop, selected, desktop-inactive, keyboard-start)
- [x] C6. Start menu cascades, Find, Run, Shut Down — all correct
- [x] C7. Folder windows, view modes, menubar, system menu, min/max, move/size — all correct
- [x] C8. Taskbar, context menus, wizard, properties, message — all correct
- [x] C9. Scales 2–4, remainder, dpi125 — all correct

### Phase D — Bugfix
- [x] D1. All confirmed bugs logged below and fixed (1 app bug: status bar CSS clip; 5 test-infra fixes)

### Phase E — Full re-verification (single clean pass)
- [x] E1. `npm run typecheck && npm test && npm run build` green (typecheck PASS; 129/129 tests; build PASS)
- [x] E2. `npm run test:visual` green: wfw-reference 0.000%, wfw-desktop 0.000%, wfw-desktop-minimized PASS, 39/39 win95 @ 0.000%
- [x] E3. Re-captures verified: status bar "5 objects" pixel-complete; multiselect deterministic {2,3,4}; selected icon highlight; About dialog; shell switch
- [x] E4. Baselines only updated after visual verification; win95 baselines regenerated at forced scale-factor 1 (640x480) after host-DPI incident

## Bug Log
- iter1 | win95 | "Run..." looks like "Bun..." | win95-start | Deep investigation: atlas glyph dump, GDI render of sserife.fon (8pt vs 10/12pt), RTM screenshots from GUIdebook (Run title bar bold R, desktop "Recycle Bin" regular R) | **NOT A BUG** — authentic RTM MS Sans Serif 8pt R is genuinely B-shaped; atlas pixel-perfect. No change.
- iter1 | test-infra | win95-selected capture showed no selection highlight | scripts/capture-wfw.cjs used `.click()`; app selects on pointerdown | scenario now dispatches `pointerdown`; selection verified (inverted label + dithered icon, RTM-correct) | scripts/capture-wfw.cjs | FIXED
- iter1 | win95 | Status bar text clipped: "5 objects" rendered as "5 object" + bottom glyph rows cut | win95-my-computer probe | `.win95-statusbar span` descendant selector leaked pane padding/border onto nested `.win95-bitmap-text` span (border-box → canvas shifted +4/+1, right side clipped) | scoped to `.win95-statusbar > span` (+ same hardening on unused `.win95-find-header` rule) | src/renderer/src/styles/win95.css | FIXED, verified pixel-complete "5 objects"
- iter1 | test-infra | win95-folder-multiselect was flaky (one batch produced {1,2,3,4} instead of {2,3,4}) | 3 pointerdowns dispatched in one JS task without awaits → React batching race | scenario now awaits 80ms between dispatches (verified deterministic {2,3,4} via probe) | scripts/capture-wfw.cjs | FIXED
- iter2 | test-infra | WFW 'about' capture opened Launcher menu instead of About dialog | menu index 3 assumed 4-menu bar; bar has 5 (Launcher added) → Help = index 4 | scripts/capture-wfw.cjs | FIXED, About dialog verified
- iter2 | test-infra | WFW scale3/scale4 captures rendered at scale 1 | fixtureScale mapping only matched 'win95-scale3/4', not 'scale3/4' | mapping extended; probe confirmed win31Scale=3 applies (wfwScale=3, menu 57px) | scripts/capture-wfw.cjs | FIXED
- iter2 | test-infra | wfw-reference size mismatch (640x420 vs 511x335) + win95 baselines captured at 800x600 | host display runs at 125% scale; capturePage returns PHYSICAL pixels (logical × 1.25) | capture script now forces `--force-device-scale-factor=1` for all views except the intentional win95-dpi125 (1.25) | scripts/capture-wfw.cjs | FIXED, deterministic on any host DPI

## Verification
- pre-loop: typecheck PASS; vitest 129/129 PASS (22 files)
- iter1: `npm run build` PASS; wfw-reference + wfw-desktop diffs explained by intentional RTM icon commit, verified visually → baselines updated; wfw-desktop-minimized PASS 0.241%
- iter1: added scripts/run-win95-visuals-report.cjs (non-stop pass/fail reporter for all 39 win95 scenarios)
- iter2: `node scripts/run-win95-visuals.cjs --update` refreshed 39 baselines post-fix; `node scripts/run-win95-visuals-report.cjs` → 39/39 PASS @ 0.000%

## Final Verification
- Exact monitor-rerunnable command: `npm run typecheck && npm test && npm run test:visual`
- Working directory: `C:/Users/vaugh/OneDrive/Desktop/Gosh-Retro-Launcher`
- Required preserved artifacts: `tests/visual/baselines/*.png`, `scripts/capture-wfw.cjs`, `scripts/run-win95-visuals.cjs`, `scripts/run-win95-visuals-report.cjs` (`out/` is regenerated by the command itself)
- Result: PASS — typecheck clean; 129/129 unit tests (22 files); wfw-reference 0.000%, wfw-desktop 0.000%, wfw-desktop-minimized pass; 39/39 Win95 scenarios passed (0.000%). Exact command above run end-to-end at 23:22 in a fresh shell context — green.

## Notes
- Font lesson: verify glyph oddities against RTM screenshots BEFORE changing anything (R-is-B is authentic Win95).
- Ground-truth reference images saved: artifacts/ref-run-win95.png, artifacts/ref-desktop-win95.png (GUIdebook).
- iter2: B3 complete (39/39 green). WFW exploration: workspace/file/about/tools/scale2-4 verified correct. Remaining WFW: Options/Window/Help menus, group window states (min/max/restore), item select/drag, properties/settings/new-group/confirm dialogs, launcher tools deep-dive. Optional fidelity note: win95 status bar says "5 objects"; RTM Explorer says "5 object(s)" — copy choice, not a bug.
