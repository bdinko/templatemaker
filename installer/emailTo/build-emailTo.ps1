<#
    build-emailTo.ps1 - build installer\emailTo\Output\emailToSetup.exe

    Stages everything the stand-alone emailTo installer ships, then compiles
    emailTo.iss with Inno Setup 6.

    The narrow (Clarion 10) build of the template is REGENERATED here rather
    than trusted: Build-NarrowTpl.ps1 exits non-zero if anything in emailTo.tpl
    has grown past what a 480 px prompt sheet can draw, and that failure must
    stop the installer being built, not be discovered by whoever installs it.

    Usage:   pwsh installer\emailTo\build-emailTo.ps1
             pwsh installer\emailTo\build-emailTo.ps1 -SkipIscc   (stage only)
#>
[CmdletBinding()]
param([switch]$SkipIscc)

$ErrorActionPreference = 'Stop'
$here    = $PSScriptRoot
$repo    = Split-Path (Split-Path $here -Parent) -Parent
$tpl     = Join-Path $repo 'templates\emailTo'
$payload = Join-Path $here 'payload'
$iss     = Join-Path $here 'emailTo.iss'

function Stage([string]$dest, [string[]]$files) {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($f in $files) { Copy-Item $f $dest -Force }
    (Get-ChildItem $dest -File).Count
}

Write-Host "==> Cleaning payload" -ForegroundColor Cyan
if (Test-Path $payload) { Remove-Item $payload -Recurse -Force }

Write-Host "==> Generating the Clarion 10 (480 px) build of the template" -ForegroundColor Cyan
& (Join-Path $tpl 'Build-NarrowTpl.ps1')
if ($LASTEXITCODE -ne 0) { throw "the narrow template build failed - emailTo.tpl no longer fits a 480 px prompt sheet" }

Write-Host "==> Staging" -ForegroundColor Cyan

$n = Stage (Join-Path $payload 'tpl')   @((Join-Path $tpl 'emailTo.tpl'))
Write-Host "    tpl       $n  (Clarion 11 forward)"

# The narrow build is deployed under the SAME name: an application records the
# template by name, and both files declare #TEMPLATE(emailTo,...).
New-Item -ItemType Directory -Force -Path (Join-Path $payload 'tpl10') | Out-Null
Copy-Item (Join-Path $tpl 'emailTo10.tpl') (Join-Path $payload 'tpl10\emailTo.tpl') -Force
Write-Host "    tpl10     1  (Clarion 10 and older)"

$classes = @(Get-ChildItem $tpl -File | Where-Object { $_.Extension -in '.inc', '.clw', '.c' })
$n = Stage (Join-Path $payload 'libsrc') $classes.FullName
Write-Host "    libsrc    $n  classes + the C file"

$dict = @('emailToTables.dctx', 'emailToTables.dct', 'emailToTables.txd', 'EmailTables.txt') |
        ForEach-Object { Join-Path $tpl $_ } | Where-Object { Test-Path $_ }
$n = Stage (Join-Path $payload 'dict') $dict
Write-Host "    dict      $n  dictionary to import"

$docs = Get-ChildItem (Join-Path $repo 'docs\emailTo') -File |
        Where-Object { $_.Extension -in '.html', '.css', '.js' }
$n = Stage (Join-Path $payload 'docs') $docs.FullName
Write-Host "    manual    $n  pages (four volumes x two languages)"

$demo = Get-ChildItem (Join-Path $repo 'examples\emailTo') -File |
        Where-Object { $_.Extension -in '.clw', '.cwproj', '.sln', '.tps' }
$n = Stage (Join-Path $payload 'examples') $demo.FullName
Write-Host "    examples  $n  demo sources"

# The classes the demos carry beside themselves are the same files staged into
# libsrc; ship them so a demo builds in the folder it is unpacked into.
Copy-Item $classes.FullName (Join-Path $payload 'examples') -Force

$version = (Select-String -Path (Join-Path $tpl 'emailTo.tpl') -Pattern "v(\d+\.\d+)" |
            Select-Object -First 1).Matches[0].Groups[1].Value
@"
emailTo for Clarion  v$version
=================================

WHAT THE INSTALLER DID
  Into every Clarion installation you ticked:
      accessory\template\win\emailTo.tpl     the template set (10 templates)
      accessory\libsrc\win\Email*.inc/.clw   the classes
      accessory\libsrc\win\emailc.c          sockets, TLS, WinHTTP, DPAPI
  and then registered the template with that installation's own ClarionCL.

  Clarion 10 and older get a build of emailTo.tpl whose prompt text is
  re-wrapped for the 480 px AppGen dialog; Clarion 11 forward get the 960 px
  one. Same template name, same generated code - only the prompt text differs.

WHERE TO START
  manual\getting-started.html      the manual, English  (four volumes)
  manual\getting-started-es.html   el manual, Espanol
  dictionary\emailToTables.dctx    import this if you want the provider's data
                                   in your own tables (Dictionary Editor >
                                   File > Import > DCTX/XML - NOT the TXD)
  examples\emailToDemo.clw         a hand-coded demo, no template needed

FIRST APPLICATION
  1. Application > Template Registry - check emailTo is listed.
  2. Global Properties > Extensions > Insert > "emailTo - Global".
  3. Fill in the Account tab (or leave it and use the Setup window at run time).
  4. Drop the "emailTo - E-mail button" control template on any window.

REMOVING IT
  Uninstall from Settings > Apps. It offers to unregister the template and
  delete the files from each Clarion it was installed into.
"@ | Set-Content (Join-Path $payload 'README.txt') -Encoding ASCII

if ($SkipIscc) { Write-Host "==> Staged only (-SkipIscc)" -ForegroundColor Yellow; return }

$iscc = @("${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
          "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
        Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $iscc) { throw "Inno Setup 6 (ISCC.exe) not found. Install it from https://jrsoftware.org/isdl.php" }

Write-Host "==> Compiling with Inno Setup" -ForegroundColor Cyan
& $iscc $iss
if ($LASTEXITCODE -ne 0) { throw "ISCC failed ($LASTEXITCODE)" }

$setup = Join-Path $here 'Output\emailToSetup.exe'
Write-Host ""
Write-Host "==> Done: $setup" -ForegroundColor Green
if (Test-Path $setup) { "    {0:N1} MB" -f ((Get-Item $setup).Length / 1MB) | Write-Host }
