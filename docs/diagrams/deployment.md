# Deployment Diagrams

Build tooling, CI/CD pipelines, and platform packaging configuration as currently implemented.

## Build Pipeline

```mermaid
flowchart TD
    subgraph "Source Code"
        MainSrc["src/main/*.ts"]
        PreloadSrc["src/preload/index.ts"]
        RendererSrc["src/renderer/src/**/*.tsx"]
        SharedSrc["src/shared/**/*.ts"]
    end

    subgraph "electron-vite Build (electron.vite.config.ts)"
        direction TB
        MainBuild["Main Build<br/>externalizeDepsPlugin()<br/>Entry: src/main/index.ts<br/>Alias: @shared -> src/shared"]
        PreloadBuild["Preload Build<br/>externalizeDepsPlugin()<br/>Entry: src/preload/index.ts<br/>Alias: @shared -> src/shared"]
        RendererBuild["Renderer Build<br/>@vitejs/plugin-react<br/>Entry: src/renderer/index.html<br/>Alias: @ -> src/renderer/src<br/>Alias: @shared -> src/shared"]
    end

    subgraph "Build Output (out/)"
        MainOut["out/main/index.js"]
        PreloadOut["out/preload/index.js"]
        RendererOut["out/renderer/index.html<br/>+ bundled JS/CSS"]
    end

    MainSrc --> MainBuild
    SharedSrc --> MainBuild
    SharedSrc --> PreloadBuild
    PreloadSrc --> PreloadBuild
    RendererSrc --> RendererBuild
    SharedSrc --> RendererBuild

    MainBuild --> MainOut
    PreloadBuild --> PreloadOut
    RendererBuild --> RendererOut
```

## Package Scripts

```mermaid
flowchart LR
    Dev["npm run dev<br/>electron-vite dev"]
    Build["npm run build<br/>electron-vite build"]
    Preview["npm run preview<br/>electron-vite preview"]
    Typecheck["npm run typecheck<br/>tsc --noEmit x3 configs"]
    Test["npm test<br/>vitest run"]

    BuildWin["npm run build:win<br/>build + electron-builder --win"]
    BuildMac["npm run build:mac<br/>build + electron-builder --mac"]
    BuildLinux["npm run build:linux<br/>build + electron-builder --linux"]

    Build --> BuildWin
    Build --> BuildMac
    Build --> BuildLinux
```

## Platform Packaging (electron-builder.yml)

```mermaid
graph TB
    EB["electron-builder<br/>appId: com.programmanager.app<br/>productName: Program Manager"]

    subgraph "Windows"
        WinTarget["Target: NSIS Installer"]
        WinArch["Architectures: x64, arm64"]
        WinIcon["Icon: resources/icon.ico"]
        WinOpts["Options:<br/>oneClick: false<br/>perMachine: false<br/>allowElevation: true<br/>allowToChangeInstallationDirectory: true<br/>createDesktopShortcut: true<br/>createStartMenuShortcut: true"]
        WinTarget --- WinArch
        WinTarget --- WinIcon
        WinTarget --- WinOpts
    end

    subgraph "macOS"
        MacTarget["Targets: DMG + ZIP"]
        MacArch["Architecture: universal"]
        MacIcon["Icon: resources/icon.icns"]
        MacOpts["Options:<br/>category: public.app-category.utilities<br/>hardenedRuntime: true<br/>notarize: true<br/>identity: signed"]
        MacTarget --- MacArch
        MacTarget --- MacIcon
        MacTarget --- MacOpts
    end

    subgraph "Linux"
        LinTarget["Targets: deb, rpm, tar.gz"]
        LinExec["executableName: program-manager"]
        LinIcon["Icon: resources/icon.png"]
        LinCat["Category: Utility"]
        LinTarget --- LinExec
        LinTarget --- LinIcon
        LinTarget --- LinCat
    end

    EB --> WinTarget
    EB --> MacTarget
    EB --> LinTarget

    subgraph "Output (dist/)"
        WinOut["*.exe (NSIS installer)"]
        MacOut["*.dmg, *.zip"]
        LinDeb["*.deb"]
        LinRpm["*.rpm"]
        LinTar["*.tar.gz"]
    end

    WinTarget --> WinOut
    MacTarget --> MacOut
    LinTarget --> LinDeb
    LinTarget --> LinRpm
    LinTarget --> LinTar
```

## CI/CD Pipeline: Linux Build

```mermaid
flowchart TD
    subgraph "Triggers"
        T1["workflow_dispatch<br/>(manual)"]
        T2["push tags: v*"]
    end

    T1 --> Matrix
    T2 --> Matrix

    subgraph "Matrix Strategy (fail-fast: false)"
        Matrix["2 jobs in parallel"]
        X64["x64<br/>ubuntu-24.04"]
        ARM64["arm64<br/>ubuntu-24.04-arm"]
        Matrix --> X64
        Matrix --> ARM64
    end

    X64 --> Steps
    ARM64 --> Steps

    subgraph "Steps (each arch)"
        Steps["Checkout (actions/checkout@v4)"]
        Steps --> Deps["Install system deps<br/>libappindicator3-dev, rpm"]
        Deps --> Node["Setup Node.js 22<br/>(actions/setup-node@v4, cache: npm)"]
        Node --> Install["npm ci"]
        Install --> TC["npm run typecheck"]
        TC --> TestStep["npm test"]
        TestStep --> BuildStep["npm run build"]
        BuildStep --> Package["npx electron-builder --linux<br/>deb rpm tar.gz --{arch}"]
    end

    subgraph "Artifacts (retention: 30 days)"
        Package --> DebArt["linux-deb-{arch}<br/>dist/*.deb"]
        Package --> RpmArt["linux-rpm-{arch}<br/>dist/*.rpm"]
        Package --> TarArt["linux-tar-gz-{arch}<br/>dist/*.tar.gz"]
    end

    subgraph "Release (tag pushes only)"
        DebArt --> Release["softprops/action-gh-release@v2<br/>Upload *.deb, *.rpm, *.tar.gz"]
        RpmArt --> Release
        TarArt --> Release
    end
```

## CI/CD Pipeline: Windows Build

```mermaid
flowchart TD
    subgraph "Triggers"
        T1["workflow_dispatch<br/>(manual)"]
        T2["push tags: v*"]
    end

    T1 --> Job
    T2 --> Job

    subgraph "Job: windows-latest"
        Job["Checkout (actions/checkout@v4)"]
        Job --> Node["Setup Node.js 22<br/>(actions/setup-node@v4, cache: npm)"]
        Node --> Install["npm ci"]
        Install --> TC["npm run typecheck"]
        TC --> TestStep["npm test"]
        TestStep --> BuildStep["npm run build"]
        BuildStep --> Package["npm run build:win --<br/>--x64 --arm64 --publish never"]
    end

    subgraph "Artifacts"
        Package --> Installer["windows-nsis-installer<br/>dist/*.exe"]
    end

    subgraph "Release (tag pushes only)"
        Installer --> Release["softprops/action-gh-release@v2<br/>Upload dist/*.exe"]
    end
```

## CI Quality Gates

Both CI workflows enforce the same quality gates before packaging:

```mermaid
flowchart LR
    A["npm ci"] --> B["Typecheck<br/>(tsc --noEmit x3)"]
    B --> C["Test<br/>(vitest run)"]
    C --> D["Build<br/>(electron-vite build)"]
    D --> E["Package<br/>(electron-builder)"]

    B -->|"Fail"| X["Pipeline stops"]
    C -->|"Fail"| X
    D -->|"Fail"| X
```

The typecheck step runs 3 separate TypeScript compiler invocations:
- `tsconfig.node.json` (main + preload + shared)
- `tsconfig.node.json --composite false` (preload standalone)
- `tsconfig.web.json` (renderer + shared)

## Testing Infrastructure

```mermaid
flowchart TB
    subgraph "Vitest Configuration (vitest.config.ts)"
        Config["globals: true<br/>alias: @shared -> src/shared"]
    end

    subgraph "Test Suites"
        Launch["src/main/ipc/__tests__/<br/>launchHandlers.test.ts<br/>tokenizeCommand, isValidExecPath"]
        StoreTest["src/main/ipc/__tests__/<br/>storeHandlers.test.ts<br/>isValidItem, isValidGroup, isValidSettings"]
        Icons["src/renderer/src/utils/__tests__/<br/>icons.test.ts"]
    end

    Config --> Launch
    Config --> StoreTest
    Config --> Icons
```

---

## Research Log

| Source File | What Was Verified |
|---|---|
| `electron.vite.config.ts` | 3 build targets (main, preload, renderer), path aliases (@shared, @), plugins (externalizeDepsPlugin, react), entry points |
| `electron-builder.yml` | Full packaging config: appId, productName, per-platform targets/architectures/icons/options, output directory (dist/), extraResources (assets/), macOS signing identity + notarization |
| `.github/workflows/build-linux.yml` | Trigger (workflow_dispatch + v* tags), matrix (x64 ubuntu-24.04 + arm64 ubuntu-24.04-arm), steps (checkout, apt deps, node 22, npm ci, typecheck, test, build, package), artifact uploads (deb/rpm/tar.gz per arch, 30-day retention), release upload on tag push |
| `.github/workflows/build-windows.yml` | Trigger (workflow_dispatch + v* tags), runner (windows-latest), steps (checkout, node 22, npm ci, typecheck, test, build, package x64+arm64), artifact upload (NSIS exe), release upload on tag push |
| `package.json` | All npm scripts (dev, build, preview, build:win/mac/linux, typecheck, test), dependencies (electron v40, react v19, zustand v5, electron-store v8, uuid v11), devDependencies (electron-vite v5, vite v7, vitest v4, typescript v5, electron-builder v26) |
| `vitest.config.ts` | globals:true, @shared alias |
| No macOS CI workflow file exists | [UNVERIFIED] macOS builds are configured in electron-builder.yml but there is no .github/workflows/build-mac.yml workflow. macOS packaging may only be done locally. |
