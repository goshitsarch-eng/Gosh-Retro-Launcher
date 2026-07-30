# Windows 95-style bitmap asset provenance

All shell PNGs in this directory are original clean-room pixel drawings created
for this project by `scripts/generate-win95-assets.cjs`. The generator consumes
only code-defined geometry and the public 16-color VGA palette. It does not
read, extract, convert, trace, embed, or derive pixels from Microsoft Windows
resources.

## Design method

The independently authored designs use the Windows 95 RTM visual grammar:
upper-left illumination, black/shadow lower-right edges, compact perspective,
opaque 16-color clusters, deliberate checker dither, and transparent masks.
Reference screenshots are used only to compare metaphor, visual bounds, color
density, perspective, and the degree of simplification between native sizes:

- Microsoft, *The Windows Interface Guidelines for Software Design* (1995),
  icon/visual design guidance in printed pp. 325–337:
  https://www.ics.uci.edu/~kobsa/courses/ICS104/course-notes/Microsoft_WindowsGuidelines.pdf
- GUIdebook’s version-separated Windows 95 RTM captures:
  https://guidebookgallery.org/guis/windows/win95
- ToastyTech’s original retail “gold” captures:
  https://toastytech.com/guis/win95.html

Original icon archives may be inspected only as a non-redistributed measurement
cross-check. They are never implementation inputs. The project does not claim
pixel identity with Microsoft artwork.

## Native sizes and generated variants

`large/*-32.png` and `small/*-16.png` are separate source designs. Small icons
are redrawn with fewer parts and stronger silhouettes; they are not reductions
of the 32px source. The 2×, 3×, and 4× PNGs are deterministic nearest-neighbor
copies from the corresponding native source, so rendering never depends on
browser resampling.

The catalog covers desktop objects, Start commands, folders/open folders,
drives, printers, primary-window/task symbols, Run, Find, Shut Down,
information/question/warning/critical messages, properties/new-shortcut flows,
URL items, and a generic launcher-application fallback.

## User-content exception

Icons extracted by the host from user-selected applications are user content,
not shell assets. `iconCatalog.ts` deliberately passes `data:`, `file:`, web,
and absolute-path icons through unchanged. They are documented exceptions and
are never used as fallbacks for built-in shell objects.

The clean-room drawings are distributed under this repository’s
AGPL-3.0-only license. Product and interface names remain trademarks of their
respective owners.
