# Win95Sans provenance

`Win95Sans` is the project-local family name for the independently recreated
FontStruction **MS Sans Serif** and **MS Sans Serif Bold** by `lou`. The webfont
copies are sourced through the MIT-licensed `jdan/98.css` project and are not
Microsoft font binaries.

- Original recreation: https://fontstruct.com/fontstructions/show/1384746
- Bold recreation: https://fontstruct.com/fontstructions/show/1384862
- Webfont source: https://github.com/jdan/98.css/tree/main/fonts
- Font license: Creative Commons Attribution-ShareAlike 3.0
- Conversion/project license: MIT

The same independently recreated source was already present for the WfW shell;
these separately named files let Win95 own its font path and rendering metrics
without changing the WfW assets.

Win95 loads the normal/bold recreations at 11 logical pixels (18px only for the
vertical Start strip), paints glyphs to an off-screen canvas, thresholds the
alpha into a one-bit mask, and composites only canonical palette colors. This
removes Chromium subpixel color fringes while supporting deterministic
measurement, clipping, wrapping, access-key underlines, disabled embossing,
desktop shadow, and integer shell scaling. A visually hidden semantic text node
and ARIA label remain beside each bitmap canvas. Editable user text retains a
native input for selection/caret/IME semantics.
