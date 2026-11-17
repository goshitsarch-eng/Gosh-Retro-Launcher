# Classic Mac OS-style icon provenance

The PNGs in `large/` and `small/` come from the Claude Design `iconsmac/` set
created for this project. They are original pixel artwork in a Classic Mac OS
visual grammar (1-bit-leaning, dithered, 32x32 and 16x16 native sizes) and are
not extracted, traced or derived from Apple resources.

`tools/import_design_icons.py` verifies that each design file is an exact 2x
nearest-neighbor enlargement of its native source and regenerates the 1x-4x
variants. The project does not claim pixel identity with Apple artwork.

`note.png` (the sticky-note icon: a yellow Stickies-style note over a pink one)
was drawn for this project in the same grammar, pixel by pixel; it is not part
of the design import. The design's alert "note" balloon is `info.png`, so
re-running the import must write that design file to `info.png`, not `note.png`.
