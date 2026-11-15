# Program Manager User Guide

Program Manager is a launcher that looks like four classic desktops: Windows for Workgroups 3.11, Windows 95, Classic Mac OS and BeOS. You organize programs, web links, scripts and folders into groups, and you start them from whichever desktop you choose.

This page is the short guide. The full manual, with screenshots, step-by-step instructions, troubleshooting and the audit findings, is the **handbook**:

> Open `docs/handbook/index.html` in any browser. It works offline, with no server or installation.

The handbook is the reference for every claim in this file. If the two ever disagree, the handbook and the source code are right, and this file should be corrected.

Version 2.0.0, revision `edb4155` plus the changes from the 2026-11-14 audit.

## Start the program

1. Install [Godot 4.7](https://godotengine.org/download). Version 4.7.2 was used for every check in the audit. The standard build is enough; .NET is not needed.
2. From the project folder, run `godot --path .`, or open `project.godot` in the editor and press F5.

On first start the program has an empty workspace and shows the Windows for Workgroups 3.11 desktop. No starter groups are created.

## Make your first group and program

On the Windows for Workgroups desktop:

1. Choose **File > New...**, select **Program Group**, and choose **OK**.
2. Type a name, such as *Utilities*, and choose **OK**. The group window opens.
3. Select the group, choose **File > New...**, select **Program Item**, and choose **OK**.
4. Fill in **Description** and **Command Line**, then choose **OK**.
5. Double-click the new icon, or select it and press **Enter**.

You can also drag a file from your file manager onto an open group window. The program fills in the name and path.

## Desktops

| Desktop | Where programs are | How to start one |
|---|---|---|
| Windows for Workgroups 3.11 | Group windows inside Program Manager | Double-click, or select and press Enter |
| Windows 95 | Start > Programs, My Computer, group windows | Start menu, double-click, or Enter |
| Classic Mac OS | Launcher HD window (a folder for each group) | Double-click; Special menu for batch launch |
| BeOS | Program Manager window; Deskbar menu | Double-click, or Enter |

Switch desktops in **Launcher Tools**, under *Shell and appearance*. Launcher Tools is in the Windows for Workgroups **Launcher** menu, in the Windows 95 Start menu under Settings, in the Mac logo menu, in the BeOS Deskbar, and with **Ctrl+Alt+T** in every desktop. Switching keeps your groups.

## Launching

- Double-click an item, or select it and press **Enter**.
- Items are started by their file type. A `.exe` runs directly, a `.bat` or `.cmd` runs through the command interpreter, a web address opens in the default browser (only `http` and `https` are accepted), and so on. The handbook lists every case.
- **Launch groups:** give an item a Launch Group from 1 to 8. **Launch All** starts every group in order. A group's own entry starts only that group. Items start one after another with a pause set in Launcher Tools (default 500 ms). There is no pause between groups, and a batch cannot be cancelled once it starts.
- **Quick Search:** press **Ctrl+Shift+Space** (**Cmd+Shift+Space** on macOS). On Windows the shortcut also works from the system tray. On macOS and Linux it works only while the program has focus, unless you bind a system shortcut to `--quick-search`.

**Known gap:** an item's Shortcut Key works only in the Windows for Workgroups desktop. A bare key such as Enter can start that item (see the handbook, CORE-02).

## Settings

There is no single Settings dialog. Each setting is changed where it lives:

- **Windows for Workgroups Options menu:** Auto Arrange (on), Minimize on Use (off), Save Settings on Exit (on).
- **Launcher Tools:** desktop, scale for each desktop, gray workspace mode, sound effects (on), minimize to tray on close (on), and the delay between batch items (500 ms).
- **Classic Mac OS:** Desktop Pictures... (six colours and dark mode). **BeOS:** Backgrounds... (six colours and dark mode).

Three settings cannot be changed from the interface: label wrapping, starter groups, and the Windows for Workgroups dark mode. Their dialog is unreachable (finding W31-001).

## Data, backups and import/export

Your data is one JSON file, `program-manager-data.json`, in a folder that depends on your system:

| System | Folder |
|---|---|
| Windows | `%APPDATA%\program-manager` |
| macOS | `~/Library/Application Support/program-manager` |
| Linux | `$XDG_CONFIG_HOME/program-manager`, or `~/.config/program-manager` |

The environment variable `PM_USER_DATA`, when set, replaces that folder on every system.

- **Automatic backups** go to a `backups` folder inside the data folder. A backup is made after a change, at most every 30 seconds. The 12 newest are kept.
- **Restore points:** Launcher Tools > *Backup and recovery*.
- **Export and import:** Launcher Tools > *Windows 3.x groups* has Export JSON..., Import JSON..., Export .GRP... and Import .GRP.... **Importing JSON replaces every group, setting and workspace profile.** The program takes a backup first. Files over 10 MB are refused.
- **Workspace profiles:** Launcher Tools > *Workspace profiles*. Applying a profile replaces every group and item without asking first. Export your data before you apply one.

## Keyboard shortcuts

| Where | Keys |
|---|---|
| Everywhere | Ctrl+Alt+T: Launcher Tools. Ctrl+Shift+Space: Quick Search (Cmd on macOS). |
| Windows for Workgroups | Alt+F, Alt+O, Alt+W, Alt+L, Alt+H open menus. Shift+F4 tiles, Shift+F5 cascades. Alt+Enter: properties. Delete: delete. |
| Windows 95 | Ctrl+Esc or Win: Start. Win+R: Run. Win+F: Find. Win+E: My Computer. Alt+Tab: switch windows. Alt+F4: close. Shift+F10: context menu. Ctrl+A: select all. |
| Classic Mac OS | Cmd+N New Folder, Cmd+O Open, Cmd+W Close, Cmd+I Get Info, Cmd+T Move To Trash, Cmd+F Find, Cmd+R Run. Delete or Backspace moves the selection to the Trash. |
| BeOS | Enter opens the selected entry. Escape cancels a dialog. |

The handbook lists every binding found in the source, with its file.

## Trash, Find and other gaps

- **Trash** on the Classic Mac OS and BeOS desktops removes only the launcher's record of an item or group. No file on disk is touched, and there is no recoverable Trash.
- **Windows 95:** Network Neighborhood, Recycle Bin, Control Panel, Printers and the Find entries for computers and the Internet show a "not available" message. Start > Documents is always empty. Find's *Include subgroups* and *Date Modified* do nothing.
- **Windows 95 Shut Down > Restart the launcher** closes the windows. It does not reload your data.

The handbook's known-gaps list and audit findings have the complete set.

## Where to go next

- **Handbook** (`docs/handbook/index.html`): the full manual, architecture, development, build and release, troubleshooting, the audit findings and the coverage of the audit.
- **README.md:** what the project is and how to run and build it.
- **docs/ARCHITECTURE.md**, **docs/PLATFORM.md**, **docs/MAC_SHELL.md**, **docs/BE_SHELL.md**: developer references. Each one notes the corrections made in the 2026-11-14 audit.
