# Windows 95 RTM launcher-shell acceptance audit

## Reference contract

The target is a clean US-English Windows 95 retail RTM (`4.00.950`) desktop at
640×480, 96 DPI, Standard color scheme. The target explicitly excludes Plus!,
OSR2/95B, Active Desktop/IE shell updates, and Windows 98. The native Electron
frame is host chrome and is outside the pixel comparison.

Behavior and control construction follow Microsoft, *The Windows Interface
Guidelines for Software Design* (1995):
[PDF](https://www.ics.uci.edu/~kobsa/courses/ICS104/course-notes/Microsoft_WindowsGuidelines.pdf).
The relevant printed sections are shell/taskbar pp. 15–21, windows pp. 75–96,
menus pp. 97–120, secondary windows pp. 143–175, visual design pp. 317–337,
and mouse/keyboard summaries pp. 357–361.

Release identity is cross-checked against:

- [GUIdebook Windows 95 release and screenshot set](https://guidebookgallery.org/guis/windows/win95), which separates Windows 95 from 95B/OSR2.
- [ToastyTech Windows 95](https://toastytech.com/guis/win95.html), explicitly described as the original retail “gold” release. Its preserved [640×480 Start capture](https://acid.im/archive/toastytech/toastytech.com/guis/win95startmenu.png) is used for geometry only because its palette is shifted.
- [PCjs Windows 95 4.00.950](https://pcjs.jdmulloy.com/software/pcx86/sys/windows/win95/4.00.950/), identified as the first retail release.
- [Microsoft shell version history](https://learn.microsoft.com/en-us/windows/win32/shell/versions): original Windows 95 uses Shell 4.0; 4.71/4.72 identify later IE-integrated/Windows 98 shells and are excluded.

All measurements below are inclusive logical-pixel geometry from the cited
lossless crop unless marked approximate. GUIdebook files are indexed PNGs with
9–16 colors and no scaling. The ToastyTech Start capture is a lossless 640×480
PNG, but its nominal 16-color palette is shifted (`#00787f` desktop,
`#bfb8bf` face); only edge positions are accepted from it.

## Source-cited acceptance matrix

| Surface | Exact reference/crop | Reference measurement | Current worktree measurement before this pass | Target token / acceptance | Intentional launcher deviation | Required deterministic scenario |
|---|---|---:|---:|---|---|---|
| Desktop/work area | [GUIdebook empty desktop, 640×480, 16 colors](https://guidebookgallery.org/pics/gui/desktop/empty/win95.png) | Desktop `#008080`; taskbar starts at y=452, so work area is 640×452 | Correct teal and 28px taskbar | `WIN95_REFERENCE_*`; `taskbarHeight=28`; exact teal through y=451 | Native Electron frame remains outside the shell | `win95` at 640×480/1× |
| Taskbar face/top | Same 640×480 crop | y=452 `#dfdfdf`, y=453 white, y=454..479 `#c0c0c0` | White row followed by `#dfdfdf` | `taskbarTopHighlight=1`; CSS edge order must be highlight then white | Tray clock shows deterministic launcher clock in captures | desktop, task states, taskbar context |
| Start button/tray | Same crop; Start cross-check in preserved gold capture above | Start outer x=2..55 = 54px, y=455..476 = 22px; tray outer x=575..637 = 63px | Start 54×22; tray minimum 62 and starts one pixel late | `startButtonWidth=54`, `startButtonHeight=22`, `trayWidth=63` | No fake notification icons | desktop and open-task captures |
| Main Start menu | [ToastyTech gold Start, 640×480, 17 shifted colors](https://acid.im/archive/toastytech/toastytech.com/guis/win95startmenu.png) | Main frame x=2..165 = 164px, y=217..451 = 235px; seven 32px command rows plus compact separator; 21px strip | Approximately 185×273, top near y=180; 36px rows | `startMenuWidth=164`, `startMenuHeight=235`, `startTopItemHeight=32`, `startSeparatorHeight=7`, `startStripWidth=21` | Programs contains launcher groups; Launcher Tools is under Settings | Start plus every submenu tier, mouse tracking, keyboard Start |
| Popup/menu rows | Microsoft menu guidance pp. 97–120; [GUIdebook file manager crop, 265×219, 16 colors](https://guidebookgallery.org/pics/gui/system/managers/filemanager/win95.png) | 20px menu bar; 20px popup item rhythm; two-pixel raised menu frame | 20px tokens but duplicated listeners and brittle nested offsets | `menuBarHeight=20`, `startSubItemHeight=20`, `menuBorder=2`; measured edge-aware placement | Only commands meaningful to launcher objects are enabled | menu bar, nested popup, contexts, disabled/default/check/radio |
| Desktop icon cells | Empty desktop crop; Microsoft visual design pp. 325–337 | 32×32 large canvases on approximately 75px columns; separately designed 16px small icons | 75px cell, but sparse same-design 16/32 drawings | `desktopIcon=32`, `desktopCellWidth=75`, `smallIcon=16`; independent clean-room sources and mask-aware selected dither | My Computer maps to launcher groups; network/recycling remain scoped notices | desktop normal/selected/focused/inactive at 1×–4× |
| System text | Microsoft visual design pp. 317–324 | MS Sans Serif 8pt, normal UI text; bold caption/default emphasis; monochrome indexed output | 11px recreation metrics are close, but Chromium introduces colored subpixel fringe and smooth rotated strip text | `systemFontPx=11`, `labelLineHeight=13`; monochrome normal/bold bitmap renderer with measured clipping/underlines/emboss/shadow | User-entered editable text may retain semantic native input editing, but shell chrome output is deterministic | desktop labels, menus, captions, dialogs, vertical strip |
| Window frame/caption | File manager crop; Microsoft windows pp. 75–96 and bevel construction pp. 328–330 | Four one-pixel raised edges begin highlight/white/face on top/left; 18px solid active caption; 16×14 caption buttons | Black outer top/left edge; inconsistent duplicated bevels; CSS-transformed glyphs | `windowFrame=3`, `captionHeight=18`, `captionButtonWidth=16`, `captionButtonHeight=14`; shared exact edge/glyph primitives | Primary windows represent launcher folders/Find rather than filesystem Explorer | active/inactive/restored/maximized/minimized/system menu/move/size |
| Folder client/status | File manager crop, 265×219 | White sunken client, 16px scrollbars, 20px status bar with size grip | Broad geometry present; native pseudo-scrollbars and fake Report header | `scrollbar=16`, `statusBarHeight=20`; deterministic list-view/header/scrollbars | Folder contents are stored launcher items/groups | all four views, selection, report resize, scrollbar interactions |
| Run | [GUIdebook Run crop, 347×163, 14 colors](https://guidebookgallery.org/pics/gui/system/features/run/win95.png) | Exact outer 347×163; caption has `?` then Close; three 75px buttons in `OK / Cancel / Browse...` order | Approximately 395×147; `Browse / OK / Cancel`; generic oversized caption Close | `runDialogWidth=347`, `runDialogHeight=163`, `buttonMinWidth=75`, exact caption controls and tab/default/cancel order | Launches a command/path through launcher APIs; history is launcher-session history | Run initial focus, combo history, Browse, validation, Enter/Escape |
| Shut Down | [GUIdebook Shut Down crop, 347×222, 11 colors](https://guidebookgallery.org/pics/gui/startupshutdown/shutdownwindow/win95.png) | Exact outer 347×222; four radio rows; `Yes / No / Help`; Close only | Approximately 391×142; invented two-choice/two-button composition | `shutdownDialogWidth=347`, `shutdownDialogHeight=222`; four-row rhythm and canonical button order | Quit and same-shell restart are supported; computer/MS-DOS/logon actions are visibly disabled and Help explains scope | every choice state, Help, No/Escape, quit/restart stubs |
| Find | [GUIdebook Find crop, 439×237, 9 colors](https://guidebookgallery.org/pics/gui/system/features/search/win95-1-1.png); gold cross-check on [ToastyTech page 2](https://toastytech.com/guis/win952.html) | Modeless primary window with `Name & Location`, `Date Modified`, `Advanced`; Find Now/Stop/New Search; results list | Simplified modal Named/results dialog with Open/Cancel and no taskbar entry | Single-instance `findWindowWidth=439`, `findWindowHeight=237` initial shell; tabs, workflow, shared list view, taskbar synchronization | Search maps to groups/items; date predicates are disabled because persisted objects have no date metadata | tabs, filters/results, Start Find/global IPC/Windows+F reuse |
| Selection rendering | [Microsoft image-list flags](https://learn.microsoft.com/en-us/windows/win32/controls/imagelistdrawflags) and [item-state semantics](https://learn.microsoft.com/en-us/windows/win32/controls/list-view-item-states) | `ILD_SELECTED == ILD_BLEND50`: 50% system-highlight blend through image mask; focused and selected states are distinct | Solid navy square plus whole-image opacity; one selected id only | Mask-aware checker/blend, active/inactive painting, focused item + selected set, range/disjoint/marquee rules | Launcher objects remain non-filesystem entities | desktop/folder normal, Ctrl/Shift/marquee, inactive selection |
| Integer scaling | Canonical measurements above; modern host extension | Canonical grid is always 1× logical | Integer transform works, but floor division exposes remainder strips and DPR selection is incomplete | 1×–4× nearest neighbor; logical viewport uses covered remainders; DPR-aware atlas/raster selection; no pointer drift | Whole-shell integer scaling is a deliberate modern accessibility feature | 2×–4×, non-divisible viewport, 125%/150% host DPI |

## Behavioral acceptance summary

- **Menus:** one controller owns Start, menu bar, system, and context menus. It
  supports press-drag-release and click-latch tracking, delayed cascade
  corridors, edge-aware nested placement, per-level Escape, mnemonics, bare
  Alt mode, wrapping arrows/Home/End, default/check/radio/disabled rows, and
  multi-column Programs overflow.
- **Input priority:** modal → menu → active primary window → desktop. Every key
  is consumed at most once. Required shell accelerators are Ctrl+Esc/Windows,
  Windows+R/F/E/Tab, Alt+Space/F4/Tab, Shift+F10/Application, and menu-bar
  access keys.
- **Desktop/list views:** distinguish focused item from selected set; support
  Ctrl/Shift/marquee/Ctrl+A/type-to-select/default action, active/inactive
  selection, context-on-release, drag image, snap/Auto Arrange, and persisted
  logical manual positions.
- **Primary windows:** single-instance activation, explicit restore, correct
  minimized task behavior, full system-menu states/default Close, outline
  move/eight-edge size with keyboard completion/cancel, maximize to the work
  area, and saved normal bounds.
- **Secondary windows:** modal backdrop, body initial focus, Win95 Tab order and
  access keys, current default button on Enter, least-destructive cancel on
  Escape/close, and transaction-on-Apply/OK behavior.

## Post-implementation disposition

The acceptance targets above are implemented in the current Win95-owned shell:
measured RTM frame/taskbar/Start/dialog geometry; monochrome bitmap shell text;
separate clean-room 16px/32px icon sources; centralized menu/input routing;
extended desktop/list selection and persisted manual positions; task/window
state synchronization and outline Move/Size; four list modes and deterministic
scrollbars; modeless single-instance Find; exact-size Run/Shut Down; property
sheets/wizard/message controls; remainder/DPI handling; pure tests; and 39
captured `win95-*` states.

No confirmed P0/P1 mismatch remains in the launcher-scoped acceptance matrix.
The following residual limitations are documented rather than hidden:

1. Editable text controls retain Chromium caret, selection, and IME painting;
   static shell text is the deterministic monochrome path.
2. Clean-room icons intentionally match RTM metaphor, perspective, bounds, and
   density rather than Microsoft resource pixels.
3. The native Electron frame and host compositor/DPI sampling are outside the
   640×480 logical shell. The app covers host remainders and keeps logical
   hit-testing integral, but cannot make every operating system draw identical
   native outer chrome.
4. Launcher objects have no real filesystem dates, hierarchy, recycle storage,
   shell clipboard/OLE data objects, network namespace, or OS session. Related
   predicates/actions stay disabled or scoped instead of fabricating data.

## Intentional launcher mappings (accepted, not fidelity gaps)

- My Computer lists launcher groups; user groups/items appear under Programs.
- Network Neighborhood, Recycle Bin, Control Panel, Printers, and unavailable
  OS operations display honest Win95-style scoped/unsupported states rather
  than fabricated filesystem, network, or recycle behavior.
- Extracted host-application icons are user content and are the documented
  exception to the project-owned clean-room shell icon catalog.
- Shut Down affects only the launcher. Optional Inbox/MSN desktop objects varied
  with installed components and are outside the default launcher surface.

## Evidence policy

Original Microsoft resources may be inspected only to understand metaphor,
visual bounds, palette density, perspective, lighting, and the relationship
between native sizes. They must not be copied, traced, embedded, or used as
inputs to generated assets. Pixel comparisons are strict for geometry,
palette, borders, and project-owned primitives; clean-room icons are accepted
by family resemblance and RTM design grammar rather than pixel identity.
