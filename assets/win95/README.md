# Win95 clean-room icon catalog

Run `node tools/generate_win95_assets.cjs` after editing
`tools/generate_win95_assets.cjs`.

- `large/*-32.png` and `small/*-16.png` are separately authored source designs.
- `64/96/128` and `32/48/64` variants are strict 2×/3×/4× nearest-neighbor output.
- Do not add extracted Microsoft resources to this directory.
- See `PROVENANCE.md` for references, clean-room boundaries, licensing, and the
  user-application-icon exception.
