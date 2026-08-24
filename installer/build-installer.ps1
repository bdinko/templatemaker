<#
    Builds the Clarion Template Tools installer.

      1. publishes the WPF designer self-contained (win-x64) into payload\app
      2. runs Inno Setup (ISCC) on ClarionTemplateTools.iss
      3. leaves ClarionTemplateToolsSetup.exe in installer\Output

    Usage:   pwsh installer\build-installer.ps1
#>
[CmdletBinding()]
param(
    [string]$Configuration = 'Release',
    [string]$Runtime       = 'win-x64'
)

$ErrorActionPreference = 'Stop'
$here    = $PSScriptRoot
$repo    = Split-Path $here -Parent
$proj    = Join-Path $repo 'designer\ClarionTplDesigner\ClarionTplDesigner.csproj'
$payload = Join-Path $here 'payload'
$appOut  = Join-Path $payload 'app'
$tplOut  = Join-Path $payload 'clarion\template'
$libOut  = Join-Path $payload 'clarion\libsrc'
$iss     = Join-Path $here 'ClarionTemplateTools.iss'

# Locate the Inno Setup compiler.
$iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $iscc) {
    throw "Inno Setup 6 (ISCC.exe) not found. Install it from https://jrsoftware.org/isdl.php"
}

Write-Host "==> Cleaning payload" -ForegroundColor Cyan
if (Test-Path $payload) { Remove-Item $payload -Recurse -Force }

Write-Host "==> Publishing designer ($Configuration / $Runtime, self-contained)" -ForegroundColor Cyan
dotnet publish $proj -c $Configuration -r $Runtime --self-contained true `
    -p:PublishSingleFile=false -p:DebugType=none -o $appOut
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }

# Clarion reads one folder per file type off the redirection path - *.tp? resolves to
# accessory\template\win and the classes to accessory\libsrc\win, neither of them
# recursively. So the repo's per-template folders get flattened here rather than being
# enumerated one Source line at a time in the .iss, which is what went stale before:
# nineteen templates were added over time and never registered for install.
Write-Host "==> Staging Clarion payload (templates + classes, flattened)" -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $tplOut, $libOut | Out-Null

$templates = Join-Path $repo 'templates'

# TestQRWnd_Renz.clw is myQRDraw's demo PROGRAM, not a class. Putting a PROGRAM on the
# redirection path would offer it to every app that compiles, so it stays out.
$notAClass = @('TestQRWnd_Renz.clw')

$stage = @(
    @{ Include = @('*.tpl', '*.png');          Dest = $tplOut; What = 'template' }
    @{ Include = @('*.inc', '*.clw', '*.c');   Dest = $libOut; What = 'class'    }
)

foreach ($set in $stage) {
    $files = Get-ChildItem $templates -Recurse -Include $set.Include |
             Where-Object { $notAClass -notcontains $_.Name }

    # Flattening is only safe while basenames are unique; a silent overwrite here would
    # ship one template's class and drop another's.
    $clash = $files | Group-Object Name | Where-Object Count -gt 1
    if ($clash) {
        $detail = ($clash | ForEach-Object { "$($_.Name): " + ($_.Group.FullName -join ', ') }) -join "`n  "
        throw "Duplicate $($set.What) file names cannot be flattened onto the redirection path:`n  $detail"
    }

    foreach ($f in $files) { Copy-Item $f.FullName $set.Dest -Force }
    Write-Host ("    {0,3} {1} files" -f $files.Count, $set.What)
}

Write-Host "==> Compiling installer with Inno Setup" -ForegroundColor Cyan
& $iscc $iss
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }

$setup = Join-Path $here 'Output\ClarionTemplateToolsSetup.exe'
Write-Host ""
Write-Host "==> Done: $setup" -ForegroundColor Green
if (Test-Path $setup) {
    "{0:N1} MB" -f ((Get-Item $setup).Length / 1MB) | Write-Host
}
