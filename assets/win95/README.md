# Win95 clean-room icon catalog

Run `node tools/generate_win95_assets.cjs` after editing
`tools/generate_win95_assets.cjs`.

- `large/*-32.png` and `small/*-16.png` are separately authored source designs.
- `64/96/128` and `32/48/64` variants are strict 2×/3×/4× nearest-neighbor output.
- Do not add extracted Microsoft resources to this directory.
- See `PROVENANCE.md` for references, clean-room boundaries, licensing, and the
  user-application-icon exception.

## Design-imported icons

The 32px/16px sources (and their 2x/3x/4x variants) were replaced by the Claude Design `icons95/` set via
`python3 tools/import_design_icons.py <design>/icons95`. That script also adds `launcher-logo` and the
`small/wfw-<id>-16.png` Windows for Workgroups application icons that the Win95 shell uses for WfW app ids
(`Win95IconCatalog.WFW_APPS`). The generator in `tools/generate_win95_assets.cjs` no longer reproduces these files.

## Sticky note icon

`large/note-*.png` and `small/note-*.png` (the `note` catalog id, used by sticky notes) are clean-room
pixel art drawn by `python3 tools/make_win95_note_icon.py`, which also writes their 2x/3x/4x variants.
