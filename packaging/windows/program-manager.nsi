; Per-user NSIS installer for the exported Godot build (replaces the electron-builder NSIS target).
;   makensis /DVERSION=2.0.0 /DARCH=x64 /DSOURCE=build\windows-x86_64\program-manager.exe /DOUTFILE=dist\Program-Manager-2.0.0-win-x64.exe packaging\windows\program-manager.nsi
Unicode true
!include "MUI2.nsh"

!ifndef VERSION
  !define VERSION "2.0.0"
!endif
!ifndef ARCH
  !define ARCH "x64"
!endif
!ifndef SOURCE
  !define SOURCE "build\windows-x86_64\program-manager.exe"
!endif
!ifndef OUTFILE
  !define OUTFILE "Program-Manager-${VERSION}-win-${ARCH}.exe"
!endif

Name "Program Manager"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\Program Manager"
InstallDirRegKey HKCU "Software\Program Manager" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma

!define MUI_ICON "..\..\resources\icon.ico"
!define MUI_UNICON "..\..\resources\icon.ico"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "$INSTDIR"
  File "/oname=Program Manager.exe" "${SOURCE}"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\Program Manager"
  CreateShortcut "$SMPROGRAMS\Program Manager\Program Manager.lnk" "$INSTDIR\Program Manager.exe"
  CreateShortcut "$DESKTOP\Program Manager.lnk" "$INSTDIR\Program Manager.exe"
  WriteRegStr HKCU "Software\Program Manager" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Program Manager" "DisplayName" "Program Manager"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Program Manager" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Program Manager" "DisplayIcon" "$INSTDIR\Program Manager.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Program Manager" "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\Program Manager.exe"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\Program Manager\Program Manager.lnk"
  RMDir "$SMPROGRAMS\Program Manager"
  Delete "$DESKTOP\Program Manager.lnk"
  DeleteRegKey HKCU "Software\Program Manager"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Program Manager"
  ; User data (%APPDATA%\program-manager) is deliberately kept.
SectionEnd
