; Скрипт Inno Setup для сборки установщика Windows-версии лаунчера.
; Перед компиляцией выполните: flutter build windows --release
;
; Компиляция установщика:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\re1999_solidleaf.iss
; Готовый установщик появится в installer\output\.

#define MyAppName "SolidLeaf Launcher"
#define MyAppVersion "0.2.0-alpha"
#define MyAppPublisher "SOLIDLEAF TEAM"
#define MyAppExeName "re_1999_solidleaf.exe"
; Путь к папке релизной сборки Flutter (относительно этого .iss).
#define BuildDir "..\build\windows\x64\runner\Release"

[Setup]
; Уникальный идентификатор приложения (не менять между версиями).
AppId={{B7B3F0B2-9C4E-4E7A-9B1A-8A3D2F5C1E10}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Иконка установщика и деинсталлятора.
SetupIconFile=..\assets\images\launcher_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
; Куда класть готовый установщик.
OutputDir=output
OutputBaseFilename=SolidLeafLauncher-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; 64-битное приложение — ставим только на x64.
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Копируем всю релизную сборку целиком (exe, dll и папку data).
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Предложить запустить приложение после установки.
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
