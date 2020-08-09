; Pixelorama Installer NSIS Script
; Copyright Xenofon Konitsas (huskee) 2020


; Helper variables so that we don't change 20 instances of the version for every update

  !define APPNAME "Pixelorama"
  !define APPVERSION "0.8-dev"
  !define COMPANYNAME "Orama Interactive"


; Include the Modern UI library
  
  !include "MUI2.nsh"


; Basic Installer Info 
  
  Name "${APPNAME} ${APPVERSION}"
  OutFile "${APPNAME}_${APPVERSION}_setup.exe"
  Unicode True

 
; Default installation folder
  
  InstallDir "$APPDATA\${COMPANYNAME}\${APPNAME}"


; Get installation folder from registry if available
  
  InstallDirRegKey HKCU "Software\${COMPANYNAME}\${APPNAME}" "InstallDir"


; Request application privileges for Vista and later
  
  RequestExecutionLevel admin


; Interface Settings 
  
  !define MUI_ICON "assets\pixel-install.ico"
  !define MUI_UNICON "assets\pixel-uninstall.ico"
  !define MUI_WELCOMEFINISHPAGE_BITMAP "assets\wizard.bmp"
  !define MUI_UNWELCOMEFINISHPAGE_BITMAP "assets\wizard.bmp"
  !define MUI_HEADERIMAGE
  !define MUI_HEADERIMAGE_RIGHT
  !define MUI_HEADERIMAGE_BITMAP "assets\header.bmp"
  !define MUI_HEADERIMAGE_UNBITMAP "assets\header.bmp"
  !define MUI_ABORTWARNING
  !define MUI_COMPONENTSPAGE_SMALLDESC
  !define MUI_FINISHPAGE_NOAUTOCLOSE
  !define MUI_UNFINISHPAGE_NOAUTOCLOSE
  !define MUI_FINISHPAGE_RUN "pixelorama.exe"

; Language selection settings
  
  !define MUI_LANGDLL_ALLLANGUAGES


; Installer pages
  
  !insertmacro MUI_PAGE_WELCOME
  !insertmacro MUI_PAGE_LICENSE "LICENSE"
  !insertmacro MUI_PAGE_COMPONENTS
  !insertmacro MUI_PAGE_DIRECTORY
  !insertmacro MUI_PAGE_INSTFILES
  !insertmacro MUI_PAGE_FINISH

  !insertmacro MUI_UNPAGE_WELCOME
  !insertmacro MUI_UNPAGE_COMPONENTS
  !insertmacro MUI_UNPAGE_CONFIRM
  !insertmacro MUI_UNPAGE_INSTFILES
  !insertmacro MUI_UNPAGE_FINISH


; Multilingual support

  !insertmacro MUI_LANGUAGE "English"
  ;@INSERT_TRANSLATIONS@
  

  ; Assign language strings to installer/uninstaller section names
    
    LangString SecInstall ${LANG_ENGLISH} "Install ${APPNAME}"
    LangString SecStartmenu ${LANG_ENGLISH} "Create Start Menu shortcuts (optional)"
    LangString SecDesktop ${LANG_ENGLISH}  "Create shortcut on Desktop (optional)"
    LangString un.SecUninstall ${LANG_ENGLISH} "Uninstall ${APPNAME} ${APPVERSION}"
    LangString un.SecConfig ${LANG_ENGLISH} "Remove configuration files (optional)"


; Installer sections

  Section "$(SecInstall)" SecInstall ; Main install section
  
  SectionIn RO ; Non optional section
    
    ; Set the installation folder as the output directory
      SetOutPath "$INSTDIR"

    ; Copy all files to install directory
      File "pixelorama.exe"
      File "pixelorama.pck"
      File "libgifexporter.windows.64.dll"

      SetOutPath "$INSTDIR\pixelorama"
      File /nonfatal /a /r "pixelorama\*"
    
    ; Store installation folder in the registry
      WriteRegStr HKCU "Software\${COMPANYNAME}\${APPNAME}" "InstallDir" $INSTDIR

    ; Create uninstaller
      WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Create Add/Remove Programs entry
      WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" \
      "DisplayName" "${APPNAME}" 
      WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" \
      "UninstallString" "$INSTDIR\Uninstall.exe"
      WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" \
      "InstallLocation" "$INSTDIR"
      WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" \
      "Publisher" "${COMPANYNAME}"
      WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" \
      "HelpLink" "https://orama-interactive.github.io/Pixelorama-Docs"
      WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" \
      "DisplayVersion" "${APPVERSION}"
      WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" \
      "NoModify" 1 
      WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" \
      "NoRepair" 1

  SectionEnd


  Section /o "$(SecStartmenu)" SecStartmenu ; Create Start Menu shortcuts

    ; Create folder in Start Menu\Programs and create shortcuts for app and uninstaller
    CreateDirectory "$SMPROGRAMS\${COMPANYNAME}"
  
    CreateShortCut "$SMPROGRAMS\${COMPANYNAME}\Pixelorama ${APPVERSION}.lnk" "$INSTDIR\Pixelorama.exe"
    CreateShortCut "$SMPROGRAMS\${COMPANYNAME}\Uninstall.lnk" "$INSTDIR\Uninstall.exe"

  SectionEnd


  Section /o "$(SecDesktop)" SecDesktop ; Create Desktop shortcut
    
    ; Create shortcut for app on desktop
      CreateShortCut "$DESKTOP\${APPNAME} ${APPVERSION}.lnk" "$INSTDIR\Pixelorama.exe"

  SectionEnd


; Installer functions

  Function .onInit
    !insertmacro MUI_LANGDLL_DISPLAY
  
  FunctionEnd


; Uninstaller sections

  Section "un.$(un.SecUninstall)" un.SecUninstall ; Main uninstall section

    SectionIn RO

    ; Delete all files and folders created by the installer
    Delete "$INSTDIR\Uninstall.exe"
    Delete "$INSTDIR\Pixelorama.exe"
    Delete "$INSTDIR\Pixelorama.pck"
    Delete "$INSTDIR\libgifexporter.windows.64.dll"
    RMDir /r "$INSTDIR\pixelorama"

    ; Delete shortcuts
    RMDir /r "$SMPROGRAMS\${COMPANYNAME}"
    Delete "$DESKTOP\${APPNAME} ${APPVERSION}.lnk"

    ; Delete the install folder
    SetOutPath "$APPDATA"
    RMDir /r "${COMPANYNAME}"

    ; If empty, delete the application's registry key
    DeleteRegKey /ifempty HKCU "Software\${COMPANYNAME}\${APPNAME}"

    ; Delete the Add/Remove Programs entry
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"

  SectionEnd


  Section "un.$(un.SecConfig)" un.SecConfig ; Configuration removal section

    ; Delete the application's settings file 
    Delete "$APPDATA\Godot\app_userdata\Pixelorama\cache.ini"

  SectionEnd

 
; Section description language strings for multilingual support
  
  LangString DESC_SecInstall ${LANG_ENGLISH} "Installs ${APPNAME} ${APPVERSION}."
  LangString DESC_SecStartmenu ${LANG_ENGLISH} "Creates Start Menu shortcuts for ${APPNAME}."
  LangString DESC_SecDesktop ${LANG_ENGLISH} "Creates a Desktop shortcut for ${APPNAME}."
  LangString DESC_un.SecUninstall ${LANG_ENGLISH} "Uninstalls ${APPNAME} ${APPVERSION} and removes all shortcuts."
  LangString DESC_un.SecConfig ${LANG_ENGLISH} "Removes configuration files for ${APPNAME}."
 
 
; Assign language strings to installer/uninstaller descriptions
  
  !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  
    !insertmacro MUI_DESCRIPTION_TEXT ${SecInstall} $(DESC_SecInstall)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecStartmenu} $(DESC_SecStartmenu)
    !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} $(DESC_SecDesktop)
  
  !insertmacro MUI_FUNCTION_DESCRIPTION_END

  
  !insertmacro MUI_UNFUNCTION_DESCRIPTION_BEGIN
  
    !insertmacro MUI_DESCRIPTION_TEXT ${un.SecUninstall} $(DESC_un.SecUninstall)
    !insertmacro MUI_DESCRIPTION_TEXT ${un.SecConfig} $(DESC_un.SecConfig)
  
  !insertmacro MUI_UNFUNCTION_DESCRIPTION_END
  
  