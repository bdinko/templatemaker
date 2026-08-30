; ============================================================================
;  emailTo for Clarion - stand-alone installer
;
;  Installs the emailTo template set (templates + classes + the C file) into
;  every Clarion installation you tick, registers it with that install's own
;  ClarionCL, and leaves the manual, the dictionary and the demos on disk.
;
;  Clarion 10 forward. Two builds of the template ship inside:
;
;      tpl\emailTo.tpl     prompts laid out for the 960 px AppGen dialog
;                          (Clarion 11, 11.1, 12 and later)
;      tpl10\emailTo.tpl   the same template with its prose re-wrapped and its
;                          captions shortened for the 480 px dialog
;                          (Clarion 10 and older)
;
;  Both declare #TEMPLATE(emailTo,...), so an application generated on one
;  machine opens on the other: only the prompt TEXT differs, never a symbol,
;  an embed or a line of generated code. templates\emailTo\Build-NarrowTpl.ps1
;  generates the narrow one and proves that.
;
;  Build it with:  installer\emailTo\build-emailTo.ps1
; ============================================================================

#define AppName      "emailTo for Clarion"
#define AppShort     "emailTo"
#define AppVersion   "1.12.0"
#define AppPublisher "Roberto Renz"

[Setup]
AppId={{3D9E5C71-8A42-4F16-B0C3-1E7A9D264B58}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppShort}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=emailToSetup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog
UninstallDisplayName={#AppName} {#AppVersion}
LicenseFile=..\..\LICENSE
DisableWelcomePage=no
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; --- what goes into the Clarion installs you tick (copied by [Code]) ---
Source: "payload\tpl\emailTo.tpl";    DestDir: "{app}\clarion\tpl";    Flags: ignoreversion
Source: "payload\tpl10\emailTo.tpl";  DestDir: "{app}\clarion\tpl10";  Flags: ignoreversion
Source: "payload\libsrc\*";           DestDir: "{app}\clarion\libsrc"; Flags: ignoreversion

; --- and what stays here for you to read, import and copy from ---
Source: "payload\docs\*";             DestDir: "{app}\manual";      Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\dict\*";             DestDir: "{app}\dictionary";  Flags: ignoreversion
Source: "payload\examples\*";         DestDir: "{app}\examples";    Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\README.txt";         DestDir: "{app}";             Flags: ignoreversion isreadme
Source: "..\..\LICENSE";              DestDir: "{app}";             Flags: ignoreversion

[Icons]
Name: "{group}\emailTo manual (English)";  Filename: "{app}\manual\getting-started.html"
Name: "{group}\Manual de emailTo (Espanol)"; Filename: "{app}\manual\getting-started-es.html"
Name: "{group}\Dictionary to import";      Filename: "{app}\dictionary"
Name: "{group}\Demo applications";         Filename: "{app}\examples"
Name: "{group}\Read me";                   Filename: "{app}\README.txt"
Name: "{group}\Uninstall {#AppName}";      Filename: "{uninstallexe}"

[Code]
const
  MinMajor = 10;                       { emailTo supports Clarion 10 forward }
  NarrowUpTo = 10;                     { <= this major gets the 480 px build }
  ManifestFile = 'emailTo-installed.txt';

type
  TClarion = record
    Root:  String;                     { C:\Clarion12 }
    Ver:   String;                     { 12.0.0.13941 }
    Major: Integer;
    Found: String;                     { how it was found, for the log }
  end;

{ Only fixed disks are scanned: a mapped network drive or a mounted image can
  take seconds to answer, and the wizard would sit there before its first page.
  An install on one is still found through the IDE settings, or added by hand. }
const
  DRIVE_FIXED = 3;

function GetDriveType(lpRootPathName: String): Cardinal;
  external 'GetDriveTypeW@kernel32.dll stdcall';

var
  Installs: array of TClarion;
  ClarionPage: TInputOptionWizardPage;
  BrowseBtn: TNewButton;
  NoneLabel: TNewStaticText;
  ResultMemo: TStringList;

{ ------------------------------------------------------------------ helpers }

function TplDirOf(const Root: String): String;
begin
  Result := AddBackslash(Root) + 'accessory\template\win';
end;

function LibDirOf(const Root: String): String;
begin
  Result := AddBackslash(Root) + 'accessory\libsrc\win';
end;

function ClarionClOf(const Root: String): String;
begin
  Result := AddBackslash(Root) + 'bin\ClarionCL.exe';
end;

{ A Clarion for Windows install is one that has the command-line tool and the
  two accessory folders the redirection file resolves *.tp? and the classes to.
  Clarion.NET shares bin\ with it and is filtered out by the same test. }
function IsClarionRoot(const Root: String): Boolean;
begin
  Result := (Root <> '') and FileExists(ClarionClOf(Root)) and DirExists(TplDirOf(Root));
end;

function MajorOf(const Ver: String): Integer;
var
  P: Integer;
begin
  P := Pos('.', Ver);
  if P > 0 then Result := StrToIntDef(Copy(Ver, 1, P - 1), 0)
  else Result := StrToIntDef(Ver, 0);
end;

function IndexOfRoot(const Root: String): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to GetArrayLength(Installs) - 1 do
    if CompareText(RemoveBackslash(Installs[I].Root), RemoveBackslash(Root)) = 0 then
    begin
      Result := I;
      Exit;
    end;
end;

procedure AddInstall(Root, How: String);
var
  N: Integer;
  Ver: String;
begin
  Root := RemoveBackslash(Trim(Root));
  if not IsClarionRoot(Root) then Exit;
  if IndexOfRoot(Root) >= 0 then Exit;
  if not GetVersionNumbersString(ClarionClOf(Root), Ver) then Ver := '';
  if MajorOf(Ver) < MinMajor then Exit;
  N := GetArrayLength(Installs);
  SetArrayLength(Installs, N + 1);
  Installs[N].Root  := Root;
  Installs[N].Ver   := Ver;
  Installs[N].Major := MajorOf(Ver);
  Installs[N].Found := How;
  Log('emailTo: found Clarion ' + Ver + ' at ' + Root + ' (' + How + ')');
end;

{ --------------------------------------------------------------- detection }

{ The IDE records every version it knows in
  %APPDATA%\SoftVelocity\Clarion\<ver>\ClarionProperties.xml, as
  <path value="C:\Clarion12\bin" /> inside a Clarion.Versions block. That
  catches installs living somewhere this installer would never think to look. }
procedure DetectFromProperties;
var
  Base, Dir, XmlFile, Line, P: String;
  Rec: TFindRec;
  Lines: TArrayOfString;
  I, A, B: Integer;
begin
  Base := AddBackslash(GetEnv('APPDATA')) + 'SoftVelocity\Clarion\';
  if not DirExists(Base) then Exit;
  if not FindFirst(Base + '*', Rec) then Exit;
  try
    repeat
      if (Rec.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then Continue;
      if (Rec.Name = '.') or (Rec.Name = '..') then Continue;
      Dir := Base + Rec.Name;
      XmlFile := AddBackslash(Dir) + 'ClarionProperties.xml';
      if not FileExists(XmlFile) then Continue;
      if not LoadStringsFromFile(XmlFile, Lines) then Continue;
      for I := 0 to GetArrayLength(Lines) - 1 do
      begin
        Line := Lines[I];
        A := Pos('<path value="', Line);
        if A = 0 then Continue;
        P := Copy(Line, A + Length('<path value="'), Length(Line));
        B := Pos('"', P);
        if B = 0 then Continue;
        P := Copy(P, 1, B - 1);
        { the recorded path is <root>\bin }
        if CompareText(ExtractFileName(RemoveBackslash(P)), 'bin') = 0 then
          AddInstall(ExtractFileDir(RemoveBackslash(P)), 'IDE settings ' + Rec.Name);
      end;
    until not FindNext(Rec);
  finally
    FindClose(Rec);
  end;
end;

{ Clarion installs to a folder off a drive root by default (C:\Clarion12), and
  people keep several side by side. Look for them, and under the two Program
  Files folders for the tidier minority. }
procedure DetectFromDisk;
var
  Drive, Base: String;
  Rec: TFindRec;
  D, K: Integer;
  Bases: array of String;
begin
  SetArrayLength(Bases, 0);
  for D := 0 to 25 do
  begin
    Drive := Chr(Ord('C') + D) + ':\';
    if D > 23 then Break;
    if DirExists(Drive) then
    begin
      K := GetArrayLength(Bases);
      SetArrayLength(Bases, K + 2);
      Bases[K]     := Drive;
      Bases[K + 1] := Drive + 'SoftVelocity\';
    end;
  end;
  K := GetArrayLength(Bases);
  SetArrayLength(Bases, K + 2);
  Bases[K]     := AddBackslash(ExpandConstant('{commonpf}')) + 'SoftVelocity\';
  Bases[K + 1] := AddBackslash(ExpandConstant('{commonpf32}')) + 'SoftVelocity\';

  for K := 0 to GetArrayLength(Bases) - 1 do
  begin
    Base := Bases[K];
    if not DirExists(Base) then Continue;
    if not FindFirst(Base + 'Clarion*', Rec) then Continue;
    try
      repeat
        if (Rec.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then Continue;
        if (Rec.Name = '.') or (Rec.Name = '..') then Continue;
        AddInstall(Base + Rec.Name, 'on disk');
      until not FindNext(Rec);
    finally
      FindClose(Rec);
    end;
  end;
end;

{ ------------------------------------------------------------- the IDE test }

function ClarionIsRunning: Boolean;
var
  Locator, WMI, Query: Variant;
begin
  Result := False;
  try
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    WMI := Locator.ConnectServer('.', 'root\cimv2');
    Query := WMI.ExecQuery('SELECT Name FROM Win32_Process WHERE Name = "Clarion.exe"');
    Result := Query.Count > 0;
  except
    Result := False;      { no WMI - say nothing rather than block the install }
  end;
end;

{ ------------------------------------------------------------------- wizard }

{ Rebuild the list without losing what is already ticked: a row added by the
  Add... button must not re-tick installs the user has just cleared. }
procedure RefreshList;
var
  I, Was: Integer;
  Kind: String;
  Keep: array of Boolean;
begin
  Was := ClarionPage.CheckListBox.Items.Count;
  SetArrayLength(Keep, GetArrayLength(Installs));
  for I := 0 to GetArrayLength(Installs) - 1 do
    if I < Was then Keep[I] := ClarionPage.Values[I]
    else Keep[I] := not WizardSilent;      { new rows: ticked, except in a silent run }

  ClarionPage.CheckListBox.Items.Clear;
  for I := 0 to GetArrayLength(Installs) - 1 do
  begin
    if Installs[I].Major <= NarrowUpTo then Kind := '480 px prompts'
    else Kind := '960 px prompts';
    ClarionPage.Add(Format('Clarion %s   %s   [%s]', [Installs[I].Ver, Installs[I].Root, Kind]));
    ClarionPage.Values[I] := Keep[I];
  end;
  NoneLabel.Visible := GetArrayLength(Installs) = 0;
end;

procedure BrowseClick(Sender: TObject);
var
  Dir, Ver: String;
begin
  Dir := '';
  if not BrowseForFolder('Pick the Clarion installation folder - the one holding bin\ClarionCL.exe', Dir, False) then Exit;
  if not IsClarionRoot(Dir) then
  begin
    MsgBox('That folder is not a Clarion installation:' + #13#10#13#10 + Dir + #13#10#13#10 +
           'Pick the folder that holds bin\ClarionCL.exe and accessory\template\win.',
           mbError, MB_OK);
    Exit;
  end;
  if not GetVersionNumbersString(ClarionClOf(Dir), Ver) then Ver := '';
  if MajorOf(Ver) < MinMajor then
  begin
    MsgBox(Format('That is Clarion %s. emailTo supports Clarion %d and later.', [Ver, MinMajor]),
           mbError, MB_OK);
    Exit;
  end;
  if IndexOfRoot(Dir) >= 0 then
  begin
    MsgBox('That installation is already in the list.', mbInformation, MB_OK);
    Exit;
  end;
  AddInstall(Dir, 'picked by hand');
  RefreshList;
end;

{ /CLARION=all           tick every detected install
  /CLARION=C:\A|C:\B     tick exactly these (adding any that were not detected)

  A silent run ticks nothing unless this is given: a machine can carry a dozen
  Clarion folders, and an unattended installer has no business guessing which
  of them someone wants a template registered into. }
procedure ApplyCommandLine;
var
  Spec, One: String;
  I, P: Integer;
begin
  Spec := ExpandConstant('{param:CLARION|}');
  if Spec = '' then
  begin
    if WizardSilent then
      Log('emailTo: silent install with no /CLARION - no Clarion installation was touched.');
    Exit;
  end;

  if CompareText(Spec, 'all') = 0 then
  begin
    for I := 0 to GetArrayLength(Installs) - 1 do ClarionPage.Values[I] := True;
    Exit;
  end;

  { add every named folder first, so one RefreshList settles the list }
  Spec := Spec + '|';
  One := '';
  repeat
    P := Pos('|', Spec);
    One := RemoveBackslash(Trim(Copy(Spec, 1, P - 1)));
    Spec := Copy(Spec, P + 1, Length(Spec));
    if One <> '' then
    begin
      if IndexOfRoot(One) < 0 then AddInstall(One, 'command line');
      if IndexOfRoot(One) < 0 then
        Log('emailTo: /CLARION named a folder that is not a Clarion ' + IntToStr(MinMajor) +
            '+ install: ' + One);
    end;
  until Spec = '';
  RefreshList;

  for I := 0 to GetArrayLength(Installs) - 1 do ClarionPage.Values[I] := False;
  Spec := ExpandConstant('{param:CLARION|}') + '|';
  repeat
    P := Pos('|', Spec);
    One := RemoveBackslash(Trim(Copy(Spec, 1, P - 1)));
    Spec := Copy(Spec, P + 1, Length(Spec));
    if One <> '' then
    begin
      I := IndexOfRoot(One);
      if I >= 0 then ClarionPage.Values[I] := True;
    end;
  until Spec = '';
end;

procedure InitializeWizard;
begin
  ResultMemo := TStringList.Create;

  DetectFromProperties;
  DetectFromDisk;

  ClarionPage := CreateInputOptionPage(wpSelectDir,
    'Clarion installations',
    'Where should emailTo be installed?',
    'Tick every Clarion installation that should get the template. Each one is registered with its own ' +
    'ClarionCL, and Clarion 10 gets the build whose prompts fit its narrower AppGen dialog.',
    False, False);

  ClarionPage.CheckListBox.Height := ScaleY(120);

  NoneLabel := TNewStaticText.Create(ClarionPage);
  NoneLabel.Parent := ClarionPage.Surface;
  NoneLabel.Top := ClarionPage.CheckListBox.Top + ScaleY(4);
  NoneLabel.Left := ClarionPage.CheckListBox.Left + ScaleX(4);
  NoneLabel.Width := ClarionPage.SurfaceWidth - ScaleX(8);
  NoneLabel.WordWrap := True;
  NoneLabel.Height := ScaleY(40);
  NoneLabel.Caption := 'No Clarion 10 (or later) installation was found. Use Add... to point at one, ' +
                       'or carry on: the manual, the dictionary and the demos are installed either way.';
  NoneLabel.Visible := False;

  BrowseBtn := TNewButton.Create(ClarionPage);
  BrowseBtn.Parent := ClarionPage.Surface;
  BrowseBtn.Top := ClarionPage.CheckListBox.Top + ClarionPage.CheckListBox.Height + ScaleY(8);
  BrowseBtn.Left := ClarionPage.CheckListBox.Left;
  BrowseBtn.Width := ScaleX(110);
  BrowseBtn.Height := ScaleY(23);
  BrowseBtn.Caption := '&Add an installation...';
  BrowseBtn.OnClick := @BrowseClick;

  RefreshList;
  ApplyCommandLine;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  I, N: Integer;
begin
  Result := True;
  if CurPageID <> ClarionPage.ID then Exit;

  N := 0;
  for I := 0 to GetArrayLength(Installs) - 1 do
    if ClarionPage.Values[I] then N := N + 1;

  if (N > 0) and ClarionIsRunning then
  begin
    if MsgBox('The Clarion IDE is running.' + #13#10#13#10 +
              'Registering a template rewrites the template registry that the IDE has open, and the IDE ' +
              'will overwrite it again when it closes - so the templates can go missing.' + #13#10#13#10 +
              'Close Clarion and press Retry, or press Cancel to install anyway.',
              mbConfirmation, MB_RETRYCANCEL) = IDRETRY then
    begin
      Result := False;
      Exit;
    end;
  end;

  if N = 0 then
    Result := SuppressibleMsgBox('No Clarion installation is ticked. The manual, the dictionary and the demos will be ' +
                     'installed, but no Clarion will get the template.' + #13#10#13#10 + 'Carry on?',
                     mbConfirmation, MB_YESNO, IDYES) = IDYES;
end;

{ --------------------------------------------------------------- installing }

function CopyLibSrc(const Dest: String): Integer;
var
  Rec: TFindRec;
  Src: String;
begin
  Result := 0;
  Src := ExpandConstant('{app}\clarion\libsrc\');
  if not FindFirst(Src + '*', Rec) then Exit;
  try
    repeat
      if (Rec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then Continue;
      if FileCopy(Src + Rec.Name, AddBackslash(Dest) + Rec.Name, False) then
      begin
        Result := Result + 1;
        ResultMemo.Add('file=' + AddBackslash(Dest) + Rec.Name);
      end
      else
        Log('emailTo: could not copy ' + Rec.Name + ' to ' + Dest);
    until not FindNext(Rec);
  finally
    FindClose(Rec);
  end;
end;

function InstallInto(const Idx: Integer; var Msg: String): Boolean;
var
  Root, TplSrc, TplDst, Lib: String;
  Code, N: Integer;
begin
  Result := False;
  Root := Installs[Idx].Root;

  if Installs[Idx].Major <= NarrowUpTo then
    TplSrc := ExpandConstant('{app}\clarion\tpl10\emailTo.tpl')
  else
    TplSrc := ExpandConstant('{app}\clarion\tpl\emailTo.tpl');

  TplDst := AddBackslash(TplDirOf(Root)) + 'emailTo.tpl';
  Lib := LibDirOf(Root);
  if not DirExists(Lib) then ForceDirectories(Lib);

  if not FileCopy(TplSrc, TplDst, False) then
  begin
    Msg := 'could not write ' + TplDst;
    Exit;
  end;
  ResultMemo.Add('root=' + Root);
  ResultMemo.Add('file=' + TplDst);

  N := CopyLibSrc(Lib);
  if N = 0 then
  begin
    Msg := 'could not write the classes into ' + Lib;
    Exit;
  end;

  { Register from the DEPLOYED path: a template registered from anywhere else
    resolves its own control templates against that other folder. }
  if not Exec(ClarionClOf(Root), '/tr "' + TplDst + '"', AddBackslash(Root) + 'bin',
              SW_HIDE, ewWaitUntilTerminated, Code) then
  begin
    Msg := 'ClarionCL would not start';
    Exit;
  end;
  if Code <> 0 then
  begin
    Msg := 'ClarionCL /tr returned ' + IntToStr(Code);
    Exit;
  end;

  Msg := Format('%d classes + emailTo.tpl (%s), registered', [N,
                 'Clarion ' + IntToStr(Installs[Idx].Major)]);
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  I, Ok, Failed: Integer;
  Msg, Report: String;
begin
  if CurStep <> ssPostInstall then Exit;

  Ok := 0; Failed := 0; Report := '';
  for I := 0 to GetArrayLength(Installs) - 1 do
  begin
    if not ClarionPage.Values[I] then Continue;
    if InstallInto(I, Msg) then
    begin
      Ok := Ok + 1;
      Report := Report + #13#10 + 'OK    ' + Installs[I].Root + '  -  ' + Msg;
      Log('emailTo: installed into ' + Installs[I].Root + ' - ' + Msg);
    end
    else
    begin
      Failed := Failed + 1;
      Report := Report + #13#10 + 'FAIL  ' + Installs[I].Root + '  -  ' + Msg;
      Log('emailTo: FAILED for ' + Installs[I].Root + ' - ' + Msg);
    end;
  end;

  if ResultMemo.Count > 0 then
    ResultMemo.SaveToFile(ExpandConstant('{app}\') + ManifestFile);

  if Failed > 0 then
    SuppressibleMsgBox('emailTo could not be installed into every Clarion you ticked.' + #13#10 + Report + #13#10#13#10 +
           'The usual causes are the IDE holding the template registry open, or the Clarion folder ' +
           'needing administrator rights.', mbError, MB_OK, IDOK)
  else if Ok > 0 then
    SuppressibleMsgBox(Format('emailTo is installed and registered in %d Clarion installation(s).', [Ok]) + Report + #13#10#13#10 +
           'In the IDE: Application > Template Registry to see it, then add ' +
           '"emailTo - Global" to an application as a global extension.', mbInformation, MB_OK, IDOK);
end;

{ ------------------------------------------------------------- uninstalling }

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Lines: TArrayOfString;
  I, Code, Stuck: Integer;
  Line, Root, F, Manifest, Report: String;
  Keep: Boolean;
begin
  if CurUninstallStep <> usUninstall then Exit;

  Manifest := ExpandConstant('{app}') + ManifestFile;
  if not FileExists(Manifest) then Exit;
  if not LoadStringsFromFile(Manifest, Lines) then Exit;

  if SuppressibleMsgBox('Also remove emailTo from the Clarion installations it was installed into?' + #13#10#13#10 +
            'This unregisters the template and deletes the template and class files. Applications that ' +
            'use emailTo will not generate until it is installed again.',
            mbConfirmation, MB_YESNO, IDYES) <> IDYES then Exit;

  Keep := True;                 { nothing to delete until a root line says otherwise }
  Stuck := 0; Report := '';
  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    Line := Lines[I];

    if Copy(Line, 1, 5) = 'root=' then
    begin
      Root := Copy(Line, 6, Length(Line));
      Keep := True;
      if not FileExists(ClarionClOf(Root)) then
      begin
        Log('emailTo: ' + Root + ' is gone - leaving its files alone');
        Continue;
      end;
      { /tu wants the template CHAIN NAME. Handed a path - even the exact path
        /tr was given - it answers "Template chain is not found" and unregisters
        nothing, and deleting the .tpl after that leaves the installation
        erroring "Could not open include file emailTo.tpl" on every generate. }
      if not Exec(ClarionClOf(Root), '/tu emailTo', AddBackslash(Root) + 'bin',
                  SW_HIDE, ewWaitUntilTerminated, Code) then Code := -1;
      Log('emailTo: /tu in ' + Root + ' returned ' + IntToStr(Code));
      if Code = 0 then
        Keep := False
      else
      begin
        Stuck := Stuck + 1;
        Report := Report + #13#10 + Root;
      end;
      Continue;
    end;

    if (Copy(Line, 1, 5) = 'file=') and not Keep then
    begin
      F := Copy(Line, 6, Length(Line));
      if FileExists(F) then DeleteFile(F);
    end;
  end;

  if Stuck > 0 then
    SuppressibleMsgBox('emailTo could not be unregistered from:' + Report + #13#10#13#10 +
      'Its files have been left in place, because deleting a template that is still registered ' +
      'leaves the installation reporting "Could not open include file emailTo.tpl". Close the ' +
      'Clarion IDE and run, from that installation''s bin folder:' + #13#10#13#10 +
      '    ClarionCL /tu emailTo', mbInformation, MB_OK, IDOK);

  DeleteFile(Manifest);
end;
