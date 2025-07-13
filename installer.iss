; Inno Setup script for ShopLite Windows Installer
; Save this as installer.iss and open with Inno Setup Compiler

[Setup]
AppName=ShopLite
AppVersion=1.0.0
DefaultDirName={commonpf}\ShopLite
DefaultGroupName=ShopLite
UninstallDisplayIcon={app}\shoplite.exe
OutputDir=.
OutputBaseFilename=ShopLiteInstaller
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ShopLite"; Filename: "{app}\shoplite.exe"
Name: "{commondesktop}\ShopLite"; Filename: "{app}\shoplite.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\shoplite.exe"; Description: "Launch ShopLite"; Flags: nowait postinstall skipifsilent
