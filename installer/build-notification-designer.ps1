<#
    Builds the Notification Designer (designer\NotificationDesigner) as one
    self-contained .exe - .NET is bundled, nothing to install - runs its tests
    first, and copies it to run\NotificationDesigner.exe.

    -Deploy also installs it where the notifications template's Design button
    looks for it: <Clarion>\accessory\bin\NotificationDesigner.exe.

    Usage:   pwsh installer\build-notification-designer.ps1 [-Deploy] [-Clarion C:\Clarion1213999,C:\clarion12]
#>
[CmdletBinding()]
param(
    [switch]$Deploy,
    [string[]]$Clarion = @('C:\Clarion1213999', 'C:\clarion12')
)

$ErrorActionPreference = 'Stop'
$repo   = Split-Path $PSScriptRoot -Parent
$proj   = Join-Path $repo 'designer\NotificationDesigner\NotificationDesigner.csproj'
$tests  = Join-Path $repo 'designer\NotificationDesigner.Tests'
$pubDir = Join-Path $PSScriptRoot 'payload\notificationdesigner'
$runDir = Join-Path $repo 'run'

Write-Host '==> Tests' -ForegroundColor Cyan
dotnet test $tests --nologo -v:q
if ($LASTEXITCODE -ne 0) { throw 'tests failed - not publishing' }

Write-Host '==> Publishing single-file (self-contained, compressed)' -ForegroundColor Cyan
Get-Process NotificationDesigner -ErrorAction SilentlyContinue | Stop-Process -Force
if (Test-Path $pubDir) { Remove-Item $pubDir -Recurse -Force }
dotnet publish $proj -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=none -o $pubDir
if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed ($LASTEXITCODE)" }

$exe = Join-Path $pubDir 'NotificationDesigner.exe'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
Copy-Item $exe (Join-Path $runDir 'NotificationDesigner.exe') -Force
Write-Host ("    run\NotificationDesigner.exe  {0:N1} MB" -f ((Get-Item $exe).Length / 1MB))

if ($Deploy) {
    foreach ($c in $Clarion) {
        $bin = Join-Path $c 'accessory\bin'
        if (-not (Test-Path $bin)) { Write-Host "    skip $c (no accessory\bin)"; continue }
        Copy-Item $exe (Join-Path $bin 'NotificationDesigner.exe') -Force
        Write-Host "    -> $bin"
    }
}
