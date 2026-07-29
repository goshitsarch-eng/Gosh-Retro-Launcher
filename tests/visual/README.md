# Visual regression baselines

`wfw-reference.png` is the measured 511×335 Windows for Workgroups Program Manager fixture. The two `wfw-desktop` captures protect windowed and minimized desktop states, while `win95-reference.png` protects the separate Win95 shell.

Run both deterministic Electron captures and compare their pixels with:

```bash
npm run test:visual
```

The harness fails when dimensions change or more than 0.5% of pixels differ by over 20 RGB levels. Update a baseline only after comparing the new capture with the supplied historical screenshots and confirming the change intentionally improves parity.
