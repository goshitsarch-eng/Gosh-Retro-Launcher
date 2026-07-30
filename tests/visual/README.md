# Visual regression baselines

`wfw-reference.png` is the measured 511×335 Windows for Workgroups Program
Manager fixture. The `wfw-desktop*` captures protect windowed/minimized desktop
states and are intentionally isolated from Win95 work.

The `win95-*` set contains 39 deterministic Windows 95 RTM launcher scenarios:

- desktop normal, selected/focused, inactive, and marquee states;
- Start keyboard state, the main menu, Programs/group tiers, and Settings;
- taskbar background/task contexts and populated task buttons;
- My Computer/group windows, all four folder views, extended selection, and
  folder context menus;
- active/inactive/restored/maximized/minimized windows, menu bar, system menu,
  and Move/Size outlines;
- modeless Find criteria pages/results, exact Run and Shut Down frames, Shortcut
  wizard, property sheet, and message box;
- 2×, 3×, and 4× shell output, a non-divisible 1281×961 viewport, and a forced
  Windows 125% device-scale capture.

The harness sends the clock component a deterministic `12:00 PM` value; it does
not replace bitmap output with browser text.

Run all suites:

```bash
npm run test:visual
```

Run only Win95:

```bash
npm run test:visual:win95
```

After reviewing every changed capture against the source-cited
`src/renderer/src/shells/win95/RTM_AUDIT.md`, update only Win95 baselines with:

```bash
npm run update:visual:win95
```

The harness fails when dimensions change or more than 0.5% of pixels differ by
more than 20 RGB levels. Never use the Win95 update command to replace
`wfw-*` baselines.
