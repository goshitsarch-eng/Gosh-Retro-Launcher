# Plan: Fix Win95 Start button white artifact + Start menu banner fidelity

## Context

In Win95 mode the Start button shows "weird white below icon" and the Start menu doesn't match real Windows 95 (user supplied `Windows_95_Start_menu.webp` RTM reference).

Investigation findings (verified against a fresh capture of the current build and pixel-level asset inspection):

1. **Start button white block — corrupted local asset.** The Start button icon resolves through `getWin95IconSrc('windows-logo', 'small', scale)`, which prefers the gitignored RTM pack (`src/renderer/src/assets/win95-rtm-local/`) over the clean-room set (`assets/win95/`). All four `win95-rtm-local/small/windows-logo-{16,32,48,64}.png` files are bad extractions: the flag is shifted right with black garbage pixels and an opaque white L-shaped block in the lower-left — that white block is exactly the "weird white below icon". The `win95-rtm-local/large/windows-logo-{32,64,96,128}.png` files are **correct** (proper waving flag with motion-trail dots, matching the RTM start button).
2. **Banner text deviation.** The menu sidebar reads `Windows 95` (with a space); RTM reads `Windows95` (no space). Source: `Win95StartMenu.tsx` renders `<Win95BitmapText text="Windows 95" bold ... vertical />`.
3. **Everything else already matches RTM.** Pixel measurement of the reference shows top-level rows are exactly 32px (same as `startTopItemHeight: 32`), menu content height within ~3px of `startMenuHeight: 235`, selection navy `#000080` matches, separator/arrows/strip width (21px) match, and the current rtm-local large menu icons are pixel-identical to the reference menu icons. No token/CSS metric changes needed. (Older artifacts in `artifacts/` and `tests/visual/baselines/` show gappy text and a flat-grid icon — those are stale, predating the RTM atlas text commit and the rtm-local icon pack; not representative of the current app.)

## Approach

- Regenerate the four corrupted `win95-rtm-local/small/windows-logo-*.png` files from the correct `win95-rtm-local/large/` versions at 2:1 (16←32, 32←64, 48←96, 64←128) using BOX resampling with an alpha threshold (≥128 → opaque, else transparent) to keep crisp pixel-art edges. Prototype already produced a 16px logo matching the reference start button (waving flag + trail dots, no white block).
- Change the banner string `Windows 95` → `Windows95` in `Win95StartMenu.tsx`.
- Optional (only if approved): also update the distributable clean-room `assets/win95/small/windows-logo-*` to include the trail dots, so non-RTM-pack builds match better. Default: leave clean-room set untouched.

## Files to modify

- `src/renderer/src/assets/win95-rtm-local/small/windows-logo-16.png` (regenerate)
- `src/renderer/src/assets/win95-rtm-local/small/windows-logo-32.png` (regenerate)
- `src/renderer/src/assets/win95-rtm-local/small/windows-logo-48.png` (regenerate)
- `src/renderer/src/assets/win95-rtm-local/small/windows-logo-64.png` (regenerate)
- `src/renderer/src/shells/win95/Win95StartMenu.tsx` (one-line banner text change)

## Reuse

- `getWin95IconSrc()` in `src/renderer/src/shells/win95/iconCatalog.ts` — no code change needed; rtm-local already shadows clean-room.
- `scripts/capture-wfw.cjs` with view `win95-start` for deterministic before/after captures.
- `Win95BitmapText` vertical rendering already matches RTM strip orientation (verified against reference).

## Steps

- [ ] Regenerate the four `win95-rtm-local/small/windows-logo-{16,32,48,64}.png` from the corresponding `large/` files (BOX 2:1 + alpha threshold), saving in place
- [ ] Magnify-check each regenerated icon on a `#c0c0c0` background against the reference start button (no white block, no black garbage, flag + trail dots visible)
- [ ] Edit `Win95StartMenu.tsx`: banner `text="Windows 95"` → `text="Windows95"`
- [ ] Capture `win95-start` view and compare side-by-side with the RTM reference (button icon, banner, menu rows)
- [ ] Run `npx vitest run` (no metric changes, so pure tests should pass unchanged)
- [ ] Delete analysis scratch files (`artifacts/_*.png`) created during planning

## Verification

- `npx electron scripts/capture-wfw.cjs artifacts/_verify-start.png win95-start` → Start button shows clean waving-flag logo with no white below it; banner reads `Windows95`; menu otherwise unchanged.
- `npx vitest run` passes.
- Note: `tests/visual/baselines/` are already stale at HEAD (they predate the RTM atlas text and the gitignored rtm-local icon pack, so local captures mismatch regardless of this change). Regenerating baselines via `node scripts/run-win95-visuals.cjs --update` is **out of scope** unless requested — flagging as pre-existing drift.
