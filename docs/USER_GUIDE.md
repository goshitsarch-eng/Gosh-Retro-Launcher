# Program Manager User Guide

Program Manager is a launcher that looks like four classic desktops: Windows for Workgroups 3.11, Windows 95, Classic Mac OS and BeOS. You organize programs, web links, scripts and folders into groups, and you start them from whichever desktop you choose.

This page is the short guide. The full manual, with screenshots, step-by-step instructions, troubleshooting and the audit findings, is the **handbook**:

> Open `docs/handbook/index.html` in any browser. It works offline, with no server or installation.

The handbook is the reference for every claim in this file. If the two ever disagree, the handbook and the source code are right, and this file should be corrected.

Version 2.0.0, revision `edb4155` plus the fixes made after the 2026-11-14 audit.

## Start the program

1. Install [Godot 4.7](https://godotengine.org/download). Version 4.7.2 was used for every check. The standard build is enough; .NET is not needed.
2. From the project folder, run `godot --path .`, or open `project.godot` in the editor and press F5.

On first start the program has an empty workspace and shows the Windows for Workgroups 3.11 desktop. No starter groups are created. The settings dialog's **Add Starter Groups** button adds them if you want them.

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
- Items are started by their file type. A `.exe` runs directly, or in its working folder when one is set. A `.bat` or `.cmd` runs through the command interpreter. A web address opens in the default browser. Only `http` and `https` addresses are accepted; on Windows any other scheme, such as `file:` or `mailto:`, is refused. The handbook lists every case.
- A program or working folder that does not exist is reported, usually before anything starts: *Program not found* or *Working directory not found*. Two exceptions on Windows. A `.exe` or `.com` with no arguments, working folder, environment variables or run mode is started directly, so a missing file gives the system's own error message instead. A `.exe` or `.com` with no arguments still starts when its working folder is missing or PowerShell is blocked, but without its working folder, environment variables or run mode.
- **Launch groups** start several programs one after another. A launch group has a number from 1 to 8, which sets the order **Launch All** runs them in, and an optional name, shown as "Group 3: Morning". A group exists while it has programs or a name, so you can name an empty group and fill it later.
  - **Manage them** in the Launch Groups window: Windows for Workgroups **Launcher > Launch Groups...**, Windows 95 **Start > Programs > Launch Groups > Manage Launch Groups...** (also Start > Settings), Classic Mac OS **Special > Launch Groups...**, BeOS Deskbar **Launch Groups...**. **New** takes the lowest free number and asks for a name. **Rename** changes the name; a blank name removes it. **Number** moves the group to another number; if that number is taken, the two groups swap. **Members** is a checklist of every program; checking a program that is in another group moves it here. **Delete** takes every program out of the group and forgets its name; the programs stay where they are. **Launch** starts the group.
  - You can still set one program's group in its Properties or Get Info dialog, and Launcher Tools has the same controls under *Launch groups*.
  - **Launch All** starts every group in number order. A group's own entry (Launch Group 3: Morning (2 items)) starts only that group. Items start one after another, with a pause set in the Settings dialog or Launcher Tools (default 500 ms). There is no pause between groups, and a batch cannot be cancelled once it starts. A group number above 8 in stored or imported data is kept, launched in order and shown as an extra choice in every item editor, so opening and saving the item does not change it.
- **Quick Search:** press **Ctrl+Shift+Space** (**Cmd+Shift+Space** on macOS). In Windows for Workgroups it opens the Quick Search box; in the other desktops it opens Find. On Windows the shortcut works system-wide, even while the window is hidden in the tray, and the tray menu has a Quick Search entry. On macOS and Linux it works only while the program has focus, unless you bind a system shortcut to `--quick-search`.

**Shortcut keys:** an item's Shortcut Key works only in the Windows for Workgroups desktop. Enter, Escape, Tab, Space, Backspace, Delete, the arrow keys, Home, End, Page Up and Page Down never start an item. The item editor does not require a modifier, so a bare key such as F5 starts the item on this desktop. Imported shortcut keys (JSON, .GRP) without Ctrl, Alt, Shift, Meta or Win before the key are cleared on import, and the import says how many.

## Settings

In the Windows for Workgroups desktop, choose **Options > Settings...**. The dialog has three groups:

- **General:** Auto Arrange icons, Minimize on Use, Save Settings on Exit, Minimize to Tray on Close, and the **Add Starter Groups** button.
- **Appearance:** Dark Mode (it applies only to the Mac OS and BeOS shells), Wrap item labels, Sound Effects, Desktop Shell, a preview, and the scale for the chosen desktop (*Program Manager Scale* for Windows for Workgroups, for example *Windows 95 Scale* for the others).
- **Batch Launch:** Delay between launches, 100 to 5000 ms.

Changes are saved when you choose **OK**. If they cannot be saved, a message box says the settings could not be applied and nothing was changed.

The other settings are changed where they appear: the Options menu (Auto Arrange, Minimize on Use, Save Settings on Exit), Launcher Tools (desktop choice, the scale of the selected desktop, WfW gray desktop mode, sound effects and minimize to tray on close under *Shell and appearance*; the delay between items under *Launch groups*), Classic Mac OS **Desktop Pictures...** and BeOS **Backgrounds...** (colour and dark mode).

## Data, backups and import/export

Your data is one JSON file, `program-manager-data.json`, in a folder that depends on your system:

| System | Folder |
|---|---|
| Windows | `%APPDATA%\program-manager` |
| macOS | `~/Library/Application Support/program-manager` |
| Linux | `$XDG_CONFIG_HOME/program-manager`, or `~/.config/program-manager` |

The environment variable `PM_USER_DATA`, when set, replaces that folder on every system.

- **Stored values are checked when the program loads.** A launch group must be a whole number of 0 or more (0 means None); a negative number, a fraction or text becomes 0. A setting with the wrong type or range takes its default, and unknown keys are kept. Every repaired value is counted, and a notice tells you how many were repaired. Imports are checked and reported the same way.
- **Automatic backups** go to a `backups` folder inside the data folder. Before a change is written, a copy of the current data is saved, at most once every 30 seconds. The 12 newest backups are kept, including manual restore points and the backups taken before a restore, import or profile.
- **Saves are never silently skipped.** If your groups, settings or workspace profiles cannot be saved, you see a notice and the error is logged. The change is kept while the program runs. Groups and settings are saved again the next time that kind is saved, when a backup or export is made, or on quit. Workspace profiles are also saved again whenever groups or settings are saved. The same notice is shown once and not repeated on every retry. A notice with a different message is shown when it occurs, and a notice is shown again after a save has worked in between.
- **Restore points:** Launcher Tools > *Backup and recovery*. **Restore asks first**: "Restore the backup from *date*? Your current data is backed up first." It writes one backup of your current data before it replaces anything. If that backup cannot be written, the restore is refused.
- **Export All and Import All** save or load everything in one file: program groups and programs, launch groups and their names, settings and workspace profiles. They are in the Windows for Workgroups **File** menu, Windows 95 **Start > Settings**, the Classic Mac OS **File** menu, the BeOS **Deskbar** menu and Launcher Tools. Export suggests a dated name such as `program-manager-export-2026-11-17.json`. **Import asks first**, because it replaces everything with the file's contents. The program then writes a backup of your current data, which you can restore from Backups in Launcher Tools. If that backup cannot be written, or the new data cannot be saved, the import is refused and nothing changes. Files over 10 MB are refused. Repaired values and cleared shortcut keys are reported. An import that switches to another desktop does not show its result message.
- **Windows 3.x groups:** Launcher Tools > *Windows 3.x groups* has Import .GRP... and Export .GRP... for one group at a time.
- **Workspace profiles:** Launcher Tools > *Workspace profiles*. **Apply asks first**: "Replace all groups and items with profile '*name*'? A backup of your current data is saved first." If that backup cannot be written, the profile is not applied.

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
- **Windows 95:** Network Neighborhood, Control Panel, Printers and the Find entries for computers and the Internet show a "not available" message. The Recycle Bin says the launcher does not keep deleted files. Start > Documents is always empty. Find's *Include subgroups* and *Date Modified* do nothing.
- **Windows 95 Shut Down > Restart the launcher** closes the windows. It does not reload your data.
- **Dark Mode** works only in the Mac OS and BeOS shells.

The handbook's known-gaps list and audit findings have the complete set.

## Where to go next

- **Handbook** (`docs/handbook/index.html`): the full manual, architecture, development, build and release, troubleshooting, the audit findings and the coverage of the audit.
- **README.md:** what the project is and how to run and build it.
- **docs/ARCHITECTURE.md**, **docs/PLATFORM.md**, **docs/MAC_SHELL.md**, **docs/BE_SHELL.md**: developer references. Each one notes the corrections made in the audit.
