# Program Manager -- User Guide

This guide covers everything you need to know to use Program Manager, a retro-styled application launcher for Windows, macOS, and Linux.

For a visual walkthrough of common workflows, see the [User Flows Diagram](diagrams/user-flows.md).

## Table of Contents

- [Getting Started](#getting-started)
- [Desktop Shells](#desktop-shells)
- [Managing Groups](#managing-groups)
- [Managing Program Items](#managing-program-items)
- [Launching Programs](#launching-programs)
- [Quick Search](#quick-search)
- [Batch Launch](#batch-launch)
- [Settings](#settings)
- [Import and Export](#import-and-export)
- [System Tray](#system-tray)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Accessibility](#accessibility)
- [Data Storage](#data-storage)
- [Troubleshooting](#troubleshooting)

---

## Getting Started

### Installing from Source

1. Install [Node.js](https://nodejs.org/) version 22 or later.
2. Clone the repository and install dependencies:
   ```bash
   git clone https://github.com/goshitsarch-eng/Gosh-Retro-Launcher.git
   cd Gosh-Retro-Launcher
   npm install
   ```
3. Start the application in development mode:
   ```bash
   npm run dev
   ```

### Installing from a Release

Pre-built packages are available from GitHub Releases:

- **Windows**: `.exe` installer (NSIS, x64 and arm64)
- **Linux**: `.deb`, `.rpm`, and `.tar.gz` packages (x64 and arm64)

> **Note**: macOS builds can be created locally with `npm run build:mac` but are not currently available as pre-built releases.

### First Launch

On your very first launch, a **Welcome dialog** appears with a quick overview of how to use the application:

- Drag files into a group window to add programs
- Use **File > New** to create items or groups
- Double-click an item to launch it
- Right-click items for properties

This dialog only appears once. After dismissing it, you will see an empty desktop with the menu bar. You can start by creating your first program group.

---

## Desktop Shells

Program Manager includes two visual shells that change the look and feel of the entire interface. You can switch between them at any time in Settings.

### Windows 3.1 Shell (Default)

The classic Windows 3.1 experience:
- **Menu bar** at the top (File, Options, Window, Help)
- **MDI (Multiple Document Interface)** desktop -- each program group opens as a draggable, resizable window on a teal desktop
- **Beveled borders** and retro styling throughout
- Menu shortcuts via Alt+F, Alt+O, Alt+W, Alt+H
- Window management: Shift+F4 to tile, Shift+F5 to cascade

### Windows 95 Shell

A Windows 95-inspired interface:
- **Taskbar** at the bottom with a Start button
- **Start menu** for accessing groups and items
- **Desktop windows** for program groups with Win95-styled chrome (minimize, maximize, close buttons)
- Status bar showing item count per group
- Resize grip in the bottom-right corner of windows

### Switching Shells

1. Open **File > Settings** (or **Help > Settings** depending on context)
2. In the **Appearance** section, find the **Desktop Shell** dropdown
3. Select either "Windows 3.1" or "Windows 95"
4. A live **Theme Preview** shows what the shell will look like
5. Click **OK** to apply

The change takes effect immediately.

---

## Managing Groups

Groups are containers for your program items. Each group appears as a window on the desktop.

### Creating a Group

1. Go to **File > New > Program Group...**
2. Enter a name for the group
3. Click **OK**

The new group appears as a window on the desktop with the default folder icon.

### Renaming a Group

1. Right-click on the group's title bar or background
2. Select **Rename** (or open group properties)
3. Enter the new name and click **OK**

### Deleting a Group

1. Right-click on the group's title bar or background
2. Select **Delete**
3. Confirm the deletion in the dialog that appears

**Warning**: Deleting a group removes all items inside it.

### Window Operations (Win31 Shell)

The Window menu provides standard MDI window management:

| Action | Menu | Shortcut |
|--------|------|----------|
| Cascade windows | Window > Cascade | Shift+F5 |
| Tile windows | Window > Tile | Shift+F4 |
| Arrange icons | Window > Arrange Icons | -- |
| Focus a specific group | Window > (group name) | -- |

You can also drag group windows by their title bar and resize them from any edge or corner.

### Group Properties

Each group has:
- **Name**: The display name shown in the title bar
- **Icon**: Choose from 80+ built-in icons or use a custom icon path

---

## Managing Program Items

Program items are the applications, scripts, or URLs that you want to launch.

### Adding Items

There are several ways to add items:

**Drag and drop**: Drag a file from your system file manager onto an open group window. The application will automatically detect the program name and path.

**File > New > Program Item...**: Opens a dialog where you can manually enter:
- Name
- Path to the executable
- Icon (pick from built-in icons or browse for a custom one)
- Working directory
- Launch group number (for batch launching)

**File > New > URL...**: Opens a dialog specifically for adding web URLs as items.

### Editing Item Properties

1. Right-click on an item
2. Select **Properties**
3. Modify any fields:
   - **Name**: Display name under the icon
   - **Path**: Full path to the executable, script, or URL
   - **Icon**: Click to open the icon picker (80+ built-in icons with search/filter, or browse for a custom icon file)
   - **Working Directory**: The directory the program runs in
   - **Launch Group**: Assign to a numbered group (1--8) for batch launching

### Deleting Items

- Select an item and press the **Delete** key
- Or right-click an item and select **Delete**
- A confirmation dialog will appear before the item is removed

### Icon Picker

The icon picker provides over 80 built-in retro-styled icons organized in a grid. You can:
- **Search/filter** icons by name using the text field at the top
- **Click** an icon to select it
- Icons include categories like: folders, web, music, video, games, tools, documents, system, and many more

Custom icons are also supported -- you can enter a file path, data URL, or web URL for any icon.

---

## Launching Programs

### Double-Click or Enter

The most common way to launch a program:
1. Double-click the program item, or
2. Select an item (single click) and press **Enter**

### What Gets Launched

Program Manager handles different file types based on your operating system:

| Platform | File Types | How It Launches |
|----------|-----------|-----------------|
| **Windows** | `.exe`, `.bat`, `.cmd` | Opens via shell |
| **Windows** | `.lnk` (shortcuts) | Reads shortcut target and launches it |
| **macOS** | `.app` bundles | Opens with `open -a` |
| **macOS** | Other executables | Spawns directly |
| **Linux** | `.desktop` files | Parses the `Exec=` line and spawns |
| **Linux** | Other executables | Spawns directly |
| **All** | `http://` or `https://` URLs | Opens in default browser |

### Minimize on Use

If the **Minimize on Use** setting is enabled, the Program Manager window will minimize after you launch a program, keeping your desktop clean.

---

## Quick Search

Quick Search lets you find and launch any program item across all groups without navigating through windows.

### Opening Quick Search

- Press **Ctrl+Shift+Space** (Windows/Linux) or **Cmd+Shift+Space** (macOS) from anywhere -- even when the app is in the background
- Or go to **Help > Quick Search...**

A hint at the bottom of the screen reminds you of the shortcut until you use it for the first time.

### Using Quick Search

1. Type your search term in the text field
2. Results appear instantly, ranked by relevance:
   - **Highest**: Items whose name starts with your search term
   - **Medium**: Items whose name contains your search term
   - **Lower**: Items whose path or group name contains your search term
3. Use **Arrow Up/Down** to navigate results
4. Press **Enter** to launch the selected item
5. Press **Escape** to close Quick Search

Up to 10 results are shown at a time. If there are more matches, a count of hidden results is displayed.

---

## Batch Launch

Batch launch lets you start multiple programs at once with a configurable delay between each.

### Setting Up Launch Groups

1. Open the properties of a program item (right-click > Properties)
2. Set the **Launch Group** field to a number from 1 to 8
3. Repeat for other items you want to batch-launch

Items with the same launch group number will launch together. Groups are launched in numerical order (group 1 first, then group 2, etc.).

### Launching

Go to **File > Launch All** to launch all items that have a launch group assigned. The delay between each launch is controlled by the **Batch Launch Delay** setting (100ms--5000ms, default 500ms).

The "Launch All" menu item is disabled if no items have a launch group assigned.

---

## Settings

Open Settings from **File > Settings...**. Settings are organized into three sections.

### General

| Setting | Description | Default |
|---------|-------------|---------|
| **Auto Arrange** | Automatically arrange icons in group windows | On |
| **Minimize on Use** | Minimize Program Manager after launching a program | Off |
| **Save Settings on Exit** | Persist window positions when closing | On |
| **Minimize to Tray on Close** | Hide to system tray instead of quitting when clicking the close button | On |

### Appearance

| Setting | Description | Default |
|---------|-------------|---------|
| **Dark Mode** | Toggle between light and dark themes | Off (light) |
| **Wrap item labels** | Show full item names (wrap) or truncate with ellipsis | Wrap |
| **Sound Effects** | Enable retro sound effects (startup chime, window sounds, clicks) | On |
| **Desktop Shell** | Choose between "Windows 3.1" and "Windows 95" | Windows 3.1 |
| **Group Title Bar Size** | Scale the window title bar from 100% to 160% | 100% |

A **Theme Preview** below the shell selector shows a miniature rendering of what the selected shell and theme combination will look like.

### Batch Launch

| Setting | Description | Default |
|---------|-------------|---------|
| **Delay between launches** | Time in milliseconds between each program launch in a batch | 500ms |

The delay slider ranges from 100ms to 5000ms in 100ms steps.

---

## Import and Export

You can back up your entire configuration (all groups, items, and settings) as a JSON file.

### Exporting

1. Go to **File > Export...**
2. Choose a location and filename (default: `program-manager-backup.json`)
3. Click **Save**

### Importing

1. Go to **File > Import...**
2. Select a previously exported JSON file
3. Click **Open**

The imported data replaces your current groups and settings. The application reloads automatically after a successful import.

**Validation**: The import process validates the structure of the JSON file before applying it. If the file is malformed or contains invalid data, an error message is shown and no changes are made.

---

## System Tray

When the **Minimize to Tray on Close** setting is enabled (default), closing the main window hides the application to the system tray instead of quitting.

### Tray Menu

Right-click the tray icon to see:
- **Show Program Manager** -- restore the main window
- A list of all your groups, each with a submenu of their items for quick launch
- **Exit** -- quit the application

### Platform Differences

| Platform | Tray Behavior |
|----------|--------------|
| **Windows** | Double-click the tray icon to restore the window |
| **Linux** | Double-click the tray icon to restore the window |
| **macOS** | Click the menu bar icon to open the tray menu. The icon automatically adapts to light/dark mode. |

### Tray Icons

The application uses platform-specific tray icons from `assets/icons/`:
- `tray-macTemplate.png` for macOS
- `tray-win.ico` for Windows
- `tray-linux.png` for Linux

If no icon file is found, a small fallback icon is used automatically.

---

## Keyboard Shortcuts

### Global (All Shells)

| Shortcut | Action |
|----------|--------|
| Ctrl+Shift+Space (Cmd+Shift+Space on macOS) | Toggle Quick Search (works even when app is in background) |
| Enter | Launch the selected program item |
| Delete | Delete the selected program item (with confirmation) |
| Arrow keys | Navigate between items in the grid |

### Windows 3.1 Shell

| Shortcut | Action |
|----------|--------|
| Alt+F | Open File menu |
| Alt+O | Open Options menu |
| Alt+W | Open Window menu |
| Alt+H | Open Help menu |
| Shift+F4 | Tile windows |
| Shift+F5 | Cascade windows |
| Escape | Close the currently open menu |

### Windows 95 Shell

| Shortcut | Action |
|----------|--------|
| Escape | Close the Start menu (when open) |

### In Dialogs

| Shortcut | Action |
|----------|--------|
| Enter | Confirm / OK |
| Escape | Cancel / Close |

### In Quick Search

| Shortcut | Action |
|----------|--------|
| Arrow Up/Down | Navigate results |
| Enter | Launch selected result |
| Escape | Close Quick Search |

---

## Accessibility

Program Manager includes several accessibility features:

- **Keyboard navigation**: All interactive elements are reachable via keyboard. Items in the grid can be navigated with arrow keys.
- **ARIA roles**: Proper roles and labels are applied to interactive elements for screen reader compatibility.
- **Focus indicators**: Visible focus rings on all interactive elements.
- **Reduced motion**: All CSS animations (window open/close, dialog transitions, menu fade-in, Start menu slide) are automatically disabled when the operating system's `prefers-reduced-motion` setting is active.
- **Sound toggle**: Sound effects can be disabled in Settings for users who prefer a silent experience.

---

## Data Storage

Program Manager stores its data using `electron-store`, which saves a JSON file in the standard application data directory for your operating system.

### File Location

The data file is named `program-manager-data.json` and is stored in:

| Platform | Location |
|----------|----------|
| **Windows** | `%APPDATA%/program-manager/` |
| **macOS** | `~/Library/Application Support/program-manager/` |
| **Linux** | `~/.config/program-manager/` |

### What Is Stored

The file contains two top-level keys:
- **groups**: All your program groups and their items
- **settings**: Your application settings

For the full data model, see the [Data Flow Diagram](diagrams/data-flow.md) or the [Data Model section in the README](../README.md#data-model).

### Resetting to Defaults

To reset the application to its default state, delete the `program-manager-data.json` file and restart the application. A fresh file with default settings will be created.

---

## Troubleshooting

### The application does not start

- Ensure you have Node.js 22+ installed: `node --version`
- Try deleting `node_modules` and reinstalling: `rm -rf node_modules && npm install`
- Check for error output in the terminal where you ran `npm run dev`

### A program item does not launch

- Verify the path is correct by checking the item's Properties (right-click > Properties)
- On Linux, `.desktop` files must have a valid `Exec=` line in the `[Desktop Entry]` section
- On Windows, `.lnk` shortcuts must point to a valid target
- On macOS, `.app` bundles must be in a location accessible to the current user
- URLs must start with `http://` or `https://`
- Check the DevTools console for error messages (run with `ELECTRON_OPEN_DEVTOOLS=1 npm run dev`)

### Sound effects are not playing

- Check that **Sound Effects** is enabled in Settings (Appearance section)
- Your browser/system audio must not be muted
- Sound effects use the Web Audio API and require user interaction (a click or keypress) before they can play. The startup chime plays after the initial data load.

### The tray icon is missing or blank

- The application looks for tray icons in `assets/icons/`. If the files are missing, a small fallback icon is used.
- On Linux, some desktop environments may not display tray icons by default. Install a system tray extension if needed.

### Data seems lost after update

- Your data file (`program-manager-data.json`) persists across updates. If data appears missing, check the file location listed in [Data Storage](#data-storage).
- You can restore from a backup if you previously used **File > Export**.

### The window is hidden and cannot be restored

- If the window is minimized to tray, look for the tray icon and double-click it (Windows/Linux) or click it (macOS).
- If the tray icon is not visible, you can kill the process and relaunch the application. The `trayOnClose` setting can be changed to `false` in the data file to prevent this behavior.

---

## Research Log

This User Guide was verified against the following source files on 2026-02-06:

| File | What Was Verified |
|------|-------------------|
| `package.json` | Scripts (dev, build, test, build:win/mac/linux, typecheck), version |
| `electron-builder.yml` | Platform build targets and output formats |
| `src/shared/types/index.ts` | ProgramItem fields (id, name, path, icon, workingDir, launchGroup), AppSettings fields and defaults, ShellType |
| `src/main/index.ts` | Global shortcut registration (Ctrl/Cmd+Shift+Space), single instance lock |
| `src/main/window.ts` | Tray-on-close behavior, DevTools env var |
| `src/main/tray.ts` | Tray icon paths, context menu structure, platform-specific double-click |
| `src/main/ipc/launchHandlers.ts` | Platform-specific launch logic (.exe, .lnk, .app, .desktop, URLs) |
| `src/main/ipc/storeHandlers.ts` | Import/export validation, default filename |
| `src/renderer/src/App.tsx` | Welcome dialog (first run via localStorage), shell resolution, theme toggle |
| `src/renderer/src/shells/registry.ts` | Two shells: "Windows 3.1" (win31), "Windows 95" (win95) |
| `src/renderer/src/shells/Win31Shell.tsx` | Alt+F/O/W/H shortcuts, Shift+F4/F5, Escape, shortcut hint |
| `src/renderer/src/shells/win95/Win95Shell.tsx` | Start menu, taskbar, Escape to close Start menu |
| `src/renderer/src/components/Menu/MenuBar.tsx` | All menu items and actions (New Group/Item/URL, Launch All, Import, Export, Settings, etc.) |
| `src/renderer/src/components/QuickSearch/QuickSearchOverlay.tsx` | Relevance ranking algorithm, max 10 results, keyboard navigation |
| `src/renderer/src/components/Dialogs/SettingsDialog.tsx` | All settings fields, slider ranges, shell selector, ThemePreview |
| `src/renderer/src/components/Dialogs/WelcomeDialog.tsx` | First-run content and instructions |
| `src/renderer/src/store/programStore.ts` | Group/item CRUD actions, debounced persistence |
| `src/renderer/src/utils/icons.ts` | 82 built-in icons in BUILTIN_ICONS array, getIconSrc resolver |
| `src/renderer/src/utils/sounds.ts` | 7 sound effect functions (startupChime, windowOpen, windowClose, menuClick, dialogOpen, errorBeep, buttonClick) |
| `src/renderer/src/utils/launchGroups.ts` | Launch group options 0--8 (0 = None) |
| `.github/workflows/build-linux.yml` | Linux x64+arm64 outputs: deb, rpm, tar.gz |
| `.github/workflows/build-windows.yml` | Windows x64+arm64 output: NSIS .exe |
