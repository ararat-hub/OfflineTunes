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
  !define APP_VERSION "1.4.1"
!endif
!ifndef FILE_VERSION
  !define FILE_VERSION "1.4.1.5"
!endif

!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\OfflineTunes"
!define DEFAULT_DIR "$LOCALAPPDATA\Programs\oTune"
Name "oTune"
OutFile "${OUTPUT_DIR}\oTune-Setup-${APP_VERSION}.exe"
InstallDir "${DEFAULT_DIR}"
RequestExecutionLevel user
SetCompressor /SOLID lzma
SetCompressorDictSize 32
ShowInstDetails show
ShowUninstDetails show
VIProductVersion "${FILE_VERSION}"
VIAddVersionKey "ProductName" "oTune"
VIAddVersionKey "FileDescription" "oTune Setup"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "oTune"

!define MUI_ABORTWARNING
!define MUI_ICON "..\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "..\windows\runner\resources\app_icon.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\oTune.exe"
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
Var PreviousInstall
Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK "oTune requires 64-bit Windows."
    Abort
  ${EndIf}
  SetRegView 64
  StrCpy $Portable "0"
  ${GetParameters} $0
  ClearErrors
  ${GetOptions} $0 "/PORTABLE" $1
  ${IfNot} ${Errors}
    StrCpy $Portable "1"
  ${Else}
    ReadRegStr $PreviousInstall HKCU "${UNINSTALL_KEY}" "InstallLocation"
    ${If} $INSTDIR == "${DEFAULT_DIR}"
    ${AndIf} $PreviousInstall != ""
    ${AndIf} ${FileExists} "$PreviousInstall\Uninstall.exe"
      StrCpy $INSTDIR $PreviousInstall
    ${EndIf}
  ${EndIf}
FunctionEnd

Section "oTune"
  SetOutPath "$INSTDIR"
  File /r /x "*.pdb" /x "*.ilk" /x "*.lib" /x "*.exp" /x "native_assets.json" /x "offlinetunes.exe" "${BUILD_DIR}\*.*"
  ${If} $Portable == "1"
    Goto finished
  ${EndIf}
  SetShellVarContext current
  ${If} $PreviousInstall == $INSTDIR
    Delete "$INSTDIR\offlinetunes.exe"
    Delete "$DESKTOP\OfflineTunes.lnk"
    Delete "$SMPROGRAMS\OfflineTunes\OfflineTunes.lnk"
    Delete "$SMPROGRAMS\OfflineTunes\Uninstall.lnk"
    RMDir "$SMPROGRAMS\OfflineTunes"
  ${EndIf}
  CreateDirectory "$SMPROGRAMS\oTune"
  CreateShortcut "$SMPROGRAMS\oTune\oTune.lnk" "$INSTDIR\oTune.exe"
  CreateShortcut "$DESKTOP\oTune.lnk" "$INSTDIR\oTune.exe"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\oTune\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "oTune"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\oTune.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  finished:
SectionEnd

Section "Uninstall"
  SetRegView 64
  SetShellVarContext current
  !include "files_uninstall.nsh"
  Delete "$DESKTOP\oTune.lnk"
  Delete "$SMPROGRAMS\oTune\oTune.lnk"
  Delete "$SMPROGRAMS\oTune\Uninstall.lnk"
  RMDir "$SMPROGRAMS\oTune"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
SectionEnd
