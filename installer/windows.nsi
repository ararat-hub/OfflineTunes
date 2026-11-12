Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "x64.nsh"

!ifndef BUILD_DIR
  !define BUILD_DIR "..\build\windows\x64\runner\Release"
!endif
!ifndef OUTPUT_DIR
  !define OUTPUT_DIR "."
!endif
!ifndef APP_VERSION
  !define APP_VERSION "1.4.0"
!endif
!ifndef FILE_VERSION
  !define FILE_VERSION "1.4.0.4"
!endif

Name "OfflineTunes"
OutFile "${OUTPUT_DIR}\OfflineTunes-Setup-${APP_VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\OfflineTunes"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 32
ShowInstDetails show
ShowUninstDetails show
VIProductVersion "${FILE_VERSION}"
VIAddVersionKey "ProductName" "OfflineTunes"
VIAddVersionKey "FileDescription" "OfflineTunes Setup"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "OfflineTunes"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\offlinetunes.exe"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "English"

Var Portable
Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK "OfflineTunes requires 64-bit Windows."
    Abort
  ${EndIf}
  SetRegView 64
  StrCpy $Portable "0"
  ${GetParameters} $0
  ClearErrors
  ${GetOptions} $0 "/PORTABLE" $1
  ${IfNot} ${Errors}
    StrCpy $Portable "1"
  ${EndIf}
FunctionEnd

Section "OfflineTunes"
  SetOutPath "$INSTDIR"
  File /r /x "*.pdb" /x "*.ilk" /x "*.lib" /x "*.exp" /x "native_assets.json" "${BUILD_DIR}\*.*"
  ${If} $Portable == "1"
    Goto finished
  ${EndIf}
  SetShellVarContext current
  CreateDirectory "$SMPROGRAMS\OfflineTunes"
  CreateShortcut "$SMPROGRAMS\OfflineTunes\OfflineTunes.lnk" "$INSTDIR\offlinetunes.exe"
  CreateShortcut "$DESKTOP\OfflineTunes.lnk" "$INSTDIR\offlinetunes.exe"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\OfflineTunes\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes" "DisplayName" "OfflineTunes"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes" "DisplayIcon" "$INSTDIR\offlinetunes.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes" "NoRepair" 1
  finished:
SectionEnd

Section "Uninstall"
  SetRegView 64
  SetShellVarContext current
  !include "files_uninstall.nsh"
  Delete "$DESKTOP\OfflineTunes.lnk"
  Delete "$SMPROGRAMS\OfflineTunes\OfflineTunes.lnk"
  Delete "$SMPROGRAMS\OfflineTunes\Uninstall.lnk"
  RMDir "$SMPROGRAMS\OfflineTunes"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes"
SectionEnd
