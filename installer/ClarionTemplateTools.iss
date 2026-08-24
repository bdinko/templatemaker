; ============================================================================
;  Clarion Template Tools - Inno Setup installer
;
;  Bundles:
;    * the Clarion Template Designer (self-contained .NET 9 WPF app)
;    * every template-authoring asset in this repo: templates, the
;      clarion-template skill, and the clarion-template-pro agent
;
;  Build it with:  installer\build-installer.ps1
;  (that script publishes the app into payload\app, then runs ISCC on this file)
; ============================================================================

#define AppName    "Clarion Template Tools"
#define AppVersion "2.15.0"
#define AppPublisher "Roberto Renz"
#define AppExe     "ClarionTplDesigner.exe"
#define ClarionTpl "C:\clarion12\accessory\template\win"
; The classes belong in ONE folder - see installer\Check-InstalledClasses.ps1 for what
; a second copy in %ROOT%\libsrc\win costs you.
#define ClarionLib "C:\clarion12\accessory\libsrc\win"

[Setup]
AppId={{8F3C1B9A-2D44-4E7C-9A1E-7C5B6E2F0A11}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=ClarionTemplateToolsSetup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayIcon={app}\{#AppExe}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut for the Template Designer"; GroupDescription: "Shortcuts:"
Name: "clarion";     Description: "Install the templates and their classes into your Clarion install ({#ClarionTpl} and {#ClarionLib})"; GroupDescription: "Template tooling:"; Check: ClarionExists
Name: "claude";      Description: "Install the clarion-template skill + clarion-template-pro agent into your ~\.claude folder"; GroupDescription: "Template tooling:"

[Files]
; --- the designer app (self-contained; no .NET runtime needed on the target) ---
Source: "payload\app\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- a local, authoritative copy of every authoring asset ---
Source: "..\templates\*"; DestDir: "{app}\templates"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\agents\*";    DestDir: "{app}\agents";    Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\skills\*";    DestDir: "{app}\skills";    Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\README.md";   DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE";     DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\*";      DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs

; --- optional: drop the templates and their classes into a detected Clarion install ---
; build-installer.ps1 flattens both sets into payload\clarion\, because Clarion resolves
; *.tp? and the class sources to one folder each and does not search below them. Staging
; there also means a new template folder needs no edit in this file.
Source: "payload\clarion\template\*"; DestDir: "{#ClarionTpl}"; Tasks: clarion; Check: ClarionExists; Flags: ignoreversion
Source: "payload\clarion\libsrc\*";   DestDir: "{#ClarionLib}"; Tasks: clarion; Check: ClarionExists; Flags: ignoreversion

; --- optional: install the Claude skill + agent into the user's profile ---
Source: "..\skills\*"; DestDir: "{%USERPROFILE}\.claude\skills"; Tasks: claude; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\agents\*"; DestDir: "{%USERPROFILE}\.claude\agents"; Tasks: claude; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Clarion Template Designer"; Filename: "{app}\{#AppExe}"
Name: "{group}\Templates folder";          Filename: "{app}\templates"
Name: "{group}\Read me";                   Filename: "{app}\README.md"
Name: "{group}\User Manual";               Filename: "{app}\docs\user-manual.html"
Name: "{group}\Programmer's Reference";    Filename: "{app}\docs\programmers-reference.html"
Name: "{autodesktop}\Clarion Template Designer"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Launch the Template Designer now"; Flags: nowait postinstall skipifsilent

[Code]
function ClarionExists: Boolean;
begin
  Result := DirExists('{#ClarionTpl}');
end;
