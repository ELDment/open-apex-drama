; ApexDrama Windows 安装器脚本（Inno Setup 6）
; 由 tool/package_windows.ps1 调用：
;   ISCC.exe /DAppVersion=1.0.2 tool\windows_installer.iss
; 产物：dist/ApexDrama-<版本>-windows-x64-setup.exe（命名与
; update_service 的 Windows 资产筛选约定一致：含 windows-x64）。

#define MyAppName "ApexDrama"
#define MyAppExe "apexduanju.exe"
#define MyAppPublisher "Sxuan-Coder"
#define MyAppURL "https://github.com/Sxuan-Coder/open-apex-drama"

#ifndef AppVersion
#define AppVersion "0.0.0"
#endif

[Setup]
AppId={{7E1A2C64-5B3D-4E8F-9A21-3F6C8D0B5A77}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppPublisher={#MyAppName}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExe}
OutputDir=..\dist
OutputBaseFilename=ApexDrama-{#AppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
MinVersion=10.0
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
; 应用自身带全量运行时/数据目录，覆盖安装不残留
UsePreviousAppDir=yes

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; \
  GroupDescription: "附加任务："

[Files]
Source: "..\build\windows\x64\runner\Release\*"; \
  DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"
Name: "{group}\卸载 {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExe}"; \
  Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "运行 {#MyAppName}"; \
  Flags: nowait postinstall skipifsilent
