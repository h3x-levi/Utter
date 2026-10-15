; Windows installer, built with Linux makensis (electron-builder's NSIS step needs Wine to run 32-bit code).
Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"

!ifndef VERSION
  !define VERSION "1.2.3"
!endif
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Utter"

Name "Utter"
!ifndef OUTFILE
  !define OUTFILE "Builds/Utter-Setup-${VERSION}.exe"
!endif
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\Utter"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "Utter ${VERSION}"

!define MUI_ICON "assets/icon.ico"
!define MUI_UNICON "assets/icon.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Welcome to Utter"
!define MUI_WELCOMEPAGE_TEXT "Utter turns your speech into text on this computer. Hold Ctrl + Windows, talk, and let go, and your words appear wherever you are typing.$\r$\n$\r$\nYour voice never leaves this computer.$\r$\n$\r$\nClick Next to continue."
!define MUI_LICENSEPAGE_TEXT_TOP "Please read the privacy notice and the license."
!define MUI_LICENSEPAGE_CHECKBOX
!define MUI_LICENSEPAGE_CHECKBOX_TEXT "I have read the privacy notice and accept the license"
!define MUI_FINISHPAGE_RUN "$INSTDIR\Utter.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Open Utter"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "installer-terms.txt"
!insertmacro MUI_PAGE_COMPONENTS
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE KeepUtterFolder
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

; Install into a folder named Utter, so the uninstaller can remove it whole without touching anything else.
Function KeepUtterFolder
  StrCpy $0 $INSTDIR "" -6
  ${If} $0 != "\Utter"
    StrCpy $INSTDIR "$INSTDIR\Utter"
  ${EndIf}
FunctionEnd

Section "Utter (required)" SecApp
  SectionIn RO
  nsExec::Exec 'taskkill /IM Utter.exe /F'
  nsExec::Exec 'taskkill /IM whisper-server.exe /F'
  SetOutPath "$INSTDIR"
  File /r "Builds/win-unpacked/*"
  WriteUninstaller "$INSTDIR\Uninstall Utter.exe"
  CreateShortcut "$SMPROGRAMS\Utter.lnk" "$INSTDIR\Utter.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Utter"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "Utter"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\Utter.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall Utter.exe"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\Utter.lnk" "$INSTDIR\Utter.exe"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecApp} "The Utter app, its speech engine and the Small English speech model."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Put an Utter shortcut on the desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; Leaves %APPDATA%\Utter (history, notes, words) in place.
Section "Uninstall"
  nsExec::Exec 'taskkill /IM Utter.exe /F'
  nsExec::Exec 'taskkill /IM whisper-server.exe /F'
  RMDir /r "$INSTDIR"
  Delete "$SMPROGRAMS\Utter.lnk"
  Delete "$DESKTOP\Utter.lnk"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
SectionEnd
