; ===============================================================================
; Script Inno Setup - Lazarus Portable Manager
; Gerador do Instalador executável (LazarusPortableSetup.exe)
; ===============================================================================

#define MyAppName "Lazarus Portable Manager"
#define MyAppVersion "2.0"
#define MyAppPublisher "ConectSolutions"
#define MyAppExeName "LazarusPortable.exe"

[Setup]
AppId={{8B19C914-7264-4E86-A1D8-92131AAFE012}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName=C:\lazarus
DisableDirPage=no
DirExistsWarning=no
DefaultGroupName={#MyAppName}
OutputDir=Output
OutputBaseFilename=LazarusPortableSetup
SetupIconFile=LazarusPortable\LazarusPortable.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Executável Principal
Source: "LazarusPortable\LazarusPortable.exe"; DestDir: "{app}"; Flags: ignoreversion

; Manual HTML
Source: "LazarusPortable\manual\MANUAL.html"; DestDir: "{app}\manual"; Flags: ignoreversion
Source: "LazarusPortable\manual\MANUAL.html"; DestDir: "{app}"; Flags: ignoreversion

; Logotipo e Imagens
Source: "LazarusPortable\logo_nova_conect.jpg"; DestDir: "{app}"; Flags: ignoreversion; Tasks: 

[Dirs]
Name: "{app}\LazarusConfig"
Name: "{app}\Backup"
Name: "{app}\Temp"
Name: "{app}\manual"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Manual do Usuário (HTML)"; Filename: "{app}\manual\MANUAL.html"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: postinstall nowait skipifsilent
