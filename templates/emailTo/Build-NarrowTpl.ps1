<#
    Build-NarrowTpl.ps1 - generate the Clarion 10 build of emailTo.tpl.

    WHY THERE ARE TWO BUILDS
    ------------------------
    AppGen draws a template's prompt sheet in a dialog whose width is fixed by the
    IDE, not by the template:

        Clarion 10 and earlier .... 480 px
        Clarion 11 forward ........ 960 px   (ClarionProperties.xml: WideAppgenDialogs)

    emailTo's prompts are written for the wide dialog. Nothing in the template
    language can ask which one it is being drawn in - a prompt sheet is parsed once,
    at registration - so the only way to fit both is to ship two builds of the file
    and let the installer pick by version. This script is the one source of the
    narrow one: emailTo.tpl in, emailTo10.tpl out.

    WHAT IT CHANGES, AND WHAT IT MUST NOT
    -------------------------------------
    It rewrites #DISPLAY text and #PROMPT captions. It touches NOTHING else: the
    self-check at the end strips both files of exactly those two kinds of line and
    demands the remainder be identical, so no generated code, embed, symbol or
    prompt USE variable can drift between the builds. An application moves between
    a Clarion 10 machine and a Clarion 12 one and sees the same template.

    THE BUDGETS, AND WHERE THEY COME FROM
    -------------------------------------
    ClientPx  452  the tab's client area at a 480-wide sheet (480 less the sheet
                   border and the 10 px margin each side).
    ProsePx   340  what prose is re-wrapped to. 25% under the client area, because
                   the IDE's font is the system font and not ours to pin down.
    LabelPx   190  a prompt caption. The label column is 200 px at 480 (it is
                   200 px in this repo's own designer preview, doubled at 960) and
                   a caption longer than its column is drawn with an ellipsis.
    StripPx   440  a sheet's row of tab headers.

    Height is deliberately NOT budgeted. The prompt sheet scrolls: the heaviest tab
    in Clarion 10's own shipped templates (ABBROWSE.TPW 'General') carries 91
    prompts inside 35 boxes, ~6x emailTo's heaviest, and has always worked.

    Text is measured, not counted, with the system font AppGen actually draws in.

    USAGE
        pwsh templates\emailTo\Build-NarrowTpl.ps1            # write emailTo10.tpl
        pwsh templates\emailTo\Build-NarrowTpl.ps1 -Check     # verify only, no write

    Exits 1 and lists every offender if anything is still over budget after the
    rules below have been applied - so a prompt added to emailTo.tpl in a year's
    time cannot silently stop fitting Clarion 10.
#>
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Out,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

if (-not $Source) { $Source = Join-Path $PSScriptRoot 'emailTo.tpl' }
if (-not $Out)    { $Out    = Join-Path $PSScriptRoot 'emailTo10.tpl' }

$ClientPx = 452
$ProsePx  = 340
$LabelPx  = 190
$StripPx  = 440
$BoxIndentPx = 12          # each #BOXED level indents its contents

# ---------------------------------------------------------------------------
#  Rules. Only text that cannot be fixed by re-wrapping needs an entry here:
#  a prompt caption (one line by definition), or a #DISPLAY line whose shape is
#  meaningful - an indented example, a column list - and so is never re-flowed.
#
#  Keep the short form saying the same thing. The manual carries the long one.
# ---------------------------------------------------------------------------
$Short = @{
    # --- prompt captions over the 190 px label column ---
    'Stamp each row with the &provider and the date' = 'Stamp &provider and date'
    '&Hide the button if the provider has no API'    = '&Hide it if there is no API'
    '&Quietly - no message when it finishes'         = '&Quietly - no message'
    '&Keep a conversation log (for support)'          = '&Keep a conversation log'
    '&Keep the provider''s data in tables'            = '&Keep the data in tables'
    'Take the file name from a variab&le:'            = 'File name from a variab&le:'
    'Take the subject from a v&ariable:'              = 'Subject from a v&ariable:'
    'Take To from a &variable instead:'               = 'To from a &variable:'
    '...or take To from this &variable:'              = '...or from this &variable:'
    '...or take it from this &variable:'              = '...or from this &variable:'
    'Take the body from a va&riable:'                 = 'Body from a va&riable:'
}

# ---------------------------------------------------------------------------
function Measure-Px([string]$text) {
    # AppGen draws captions with the system UI font; the mnemonic '&' is not drawn.
    $t = $text -replace '&&', "`u{0001}" -replace '&', '' -replace "`u{0001}", '&'
    $sz = [System.Windows.Forms.TextRenderer]::MeasureText(
              $t, $script:Font, [System.Drawing.Size]::new(10000, 100),
              [System.Windows.Forms.TextFormatFlags]::NoPadding)
    return $sz.Width
}

function Split-Words([string]$text, [int]$budget) {
    # Greedy wrap. Never splits a word: an unbreakable word longer than the budget
    # is reported by the checker rather than mangled here.
    $acc = @(); $line = ''
    foreach ($w in ($text -split ' +')) {
        if ($w -eq '') { continue }
        $try = if ($line -eq '') { $w } else { "$line $w" }
        if ((Measure-Px $try) -le $budget) { $line = $try }
        else { if ($line -ne '') { $acc += $line }; $line = $w }
    }
    if ($line -ne '') { $acc += $line }
    return ,$acc
}

function Unescape([string]$s) { $s -replace "''", "'" }
function Escapee([string]$s)  { $s -replace "'", "''" }

$script:Font = New-Object System.Drawing.Font('Segoe UI', 9)

# --- read (Clarion source is Windows-1252 + CRLF, and stays that way) ----------
$enc   = [System.Text.Encoding]::GetEncoding(1252)
$text  = $enc.GetString([System.IO.File]::ReadAllBytes($Source))
$lines = $text.Split([string[]]@("`r`n"), [System.StringSplitOptions]::None)

$reDisplay = "^(?<i>\s*)#DISPLAY\('(?<t>(?:[^']|'')*)'\)\s*$"
$rePrompt  = "^(?<i>\s*)#PROMPT\('(?<t>(?:[^']|'')*)'(?<rest>.*)$"
$reTab     = "^\s*#TAB\('(?<t>(?:[^']|'')*)'"
$reSect    = "^\s*#(TEMPLATE|EXTENSION|CONTROL|CODE|GROUP)\((?<n>[^,)]+)"

# --- pass 1: rewrite -----------------------------------------------------------
$doc = New-Object System.Collections.Generic.List[string]
$depth = 0; $sect = ''; $tab = ''
$run = New-Object System.Collections.Generic.List[object]   # a contiguous prose run
$applied = @{}
$stats = [ordered]@{ prose = 0; wrapped = 0; captions = 0 }

function Flush-Run {
    if ($script:run.Count -eq 0) { return }
    $indent = $script:run[0].indent
    $budget = $ProsePx - ($script:run[0].depth * $BoxIndentPx)

    # A run is re-flowed only when every line of it is ordinary prose. A line that
    # starts with spaces inside the literal is deliberate shape - an indented
    # example, a column list - and is copied through untouched (and checked).
    $reflow = $true
    foreach ($r in $script:run) { if ($r.text -match '^\s') { $reflow = $false } }

    if ($reflow) {
        $joined = (($script:run | ForEach-Object { $_.text }) -join ' ').Trim()
        $wrapped = Split-Words $joined $budget
        foreach ($w in $wrapped) { $script:doc.Add("$indent#DISPLAY('$(Escapee $w)')") }
        $script:stats.prose += $script:run.Count
        $script:stats.wrapped += $wrapped.Count
    } else {
        foreach ($r in $script:run) {
            $t = $r.text
            if ($Short.ContainsKey($t)) { $t = $Short[$t]; $applied[$r.text] = $true }
            $script:doc.Add("$($r.indent)#DISPLAY('$(Escapee $t)')")
        }
    }
    $script:run.Clear()
}

foreach ($ln in $lines) {
    $m = [regex]::Match($ln, $reSect)
    if ($m.Success) { Flush-Run; $sect = $m.Groups['n'].Value; $depth = 0 }
    $m = [regex]::Match($ln, $reTab)
    if ($m.Success) { Flush-Run; $tab = $m.Groups['t'].Value }

    if ($ln -match '^\s*#BOXED')    { Flush-Run; $depth++ }
    if ($ln -match '^\s*#ENDBOXED') { Flush-Run; $depth = [Math]::Max(0, $depth - 1) }

    $m = [regex]::Match($ln, $reDisplay)
    if ($m.Success) {
        $t = Unescape $m.Groups['t'].Value
        if ($t.Trim() -eq '') { Flush-Run; $doc.Add($ln); continue }     # blank line = paragraph break
        $run.Add([pscustomobject]@{ indent = $m.Groups['i'].Value; text = $t; depth = $depth })
        continue
    }
    Flush-Run

    $m = [regex]::Match($ln, $rePrompt)
    if ($m.Success) {
        $cap = Unescape $m.Groups['t'].Value
        if ($Short.ContainsKey($cap)) {
            $applied[$cap] = $true; $stats.captions++
            $doc.Add("$($m.Groups['i'].Value)#PROMPT('$(Escapee $Short[$cap])'$($m.Groups['rest'].Value)")
            continue
        }
    }

    # The version banner says which build this is, so a support question can be
    # answered from a screenshot of the tab.
    if ($ln -match "^(\s*)#DISPLAY\('(emailTo v[0-9.]+.*)'\)$") { }   # handled above as prose
    $doc.Add($ln)
}
Flush-Run

# The one deliberate difference in wording: mark the build on every version banner.
for ($i = 0; $i -lt $doc.Count; $i++) {
    if ($doc[$i] -match "^(?<i>\s*)#DISPLAY\('(?<v>emailTo v[0-9.]+[^']*)'\)$") {
        $doc[$i] = "$($Matches['i'])#DISPLAY('$($Matches['v'])  [480]')"
    }
}
$hdr = $doc[0]
if ($hdr -match "^#TEMPLATE\((?<n>[^,]+),'(?<d>(?:[^']|'')*)'\)(?<rest>.*)$") {
    $doc[0] = "#TEMPLATE($($Matches['n']),'$($Matches['d']) - Clarion 10 (480) layout')$($Matches['rest'])"
}

# --- pass 2: check -------------------------------------------------------------
$bad = New-Object System.Collections.Generic.List[string]
$depth = 0; $sect = ''; $tab = ''; $strip = @{}; $stripOrder = @()
for ($i = 0; $i -lt $doc.Count; $i++) {
    $ln = $doc[$i]
    $m = [regex]::Match($ln, $reSect);  if ($m.Success) { $sect = $m.Groups['n'].Value; $depth = 0 }
    $m = [regex]::Match($ln, $reTab)
    if ($m.Success) {
        $tab = $m.Groups['t'].Value
        if (-not $strip.ContainsKey($sect)) { $strip[$sect] = 0; $stripOrder += $sect }
        $strip[$sect] += (Measure-Px (Unescape $tab)) + 14      # header padding
    }
    if ($ln -match '^\s*#ENDBOXED') { $depth = [Math]::Max(0, $depth - 1) }
    if ($ln -match '^\s*#BOXED') {
        $depth++
        # A box title is drawn on the frame and clips like anything else.
        $mb = [regex]::Match($ln, "^\s*#BOXED\('(?<t>(?:[^']|'')*)'")
        if ($mb.Success) {
            $bt = Unescape $mb.Groups['t'].Value
            $w = (Measure-Px $bt) + ($depth * $BoxIndentPx)
            if ($w -gt $ClientPx) { $bad.Add(("{0,4} px  {1}/{2}  #BOXED    {3}" -f $w, $sect, $tab, $bt)) }
        }
    }

    $m = [regex]::Match($ln, $reDisplay)
    if ($m.Success) {
        $t = Unescape $m.Groups['t'].Value
        $w = (Measure-Px $t) + ($depth * $BoxIndentPx)
        if ($w -gt $ClientPx) { $bad.Add(("{0,4} px  {1}/{2}  #DISPLAY  {3}" -f $w, $sect, $tab, $t)) }
        continue
    }
    $m = [regex]::Match($ln, $rePrompt)
    if ($m.Success) {
        $t = Unescape $m.Groups['t'].Value
        $w = Measure-Px $t
        if ($w -gt $LabelPx) { $bad.Add(("{0,4} px  {1}/{2}  #PROMPT   {3}" -f $w, $sect, $tab, $t)) }
    }
}
foreach ($s in $stripOrder) {
    if ($strip[$s] -gt $StripPx) { $bad.Add(("{0,4} px  {1}  tab header strip" -f $strip[$s], $s)) }
}

# --- pass 3: self-check - only prompt text may differ between the builds --------
function Skeleton([string[]]$src) {
    # A run of #DISPLAY lines collapses to ONE token: re-wrapping is allowed to change
    # how many lines a paragraph takes, and nothing else is allowed to change at all.
    $keep = New-Object System.Collections.Generic.List[string]
    $inDisplay = $false
    foreach ($l in $src) {
        if ($l -match $reDisplay) {
            if (-not $inDisplay) { $keep.Add('#DISPLAY-BLOCK'); $inDisplay = $true }
            continue
        }
        $inDisplay = $false
        $m = [regex]::Match($l, $rePrompt)
        if ($m.Success) { $keep.Add("#PROMPT$($m.Groups['rest'].Value)"); continue }
        if ($l -match "^#TEMPLATE\(") { $keep.Add('#TEMPLATE'); continue }
        $keep.Add($l)
    }
    return ($keep -join "`n")
}
$a = Skeleton $lines
$b = Skeleton $doc
if ($a -ne $b) {
    $la = $a -split "`n"; $lb = $b -split "`n"
    $bad.Add("SELF-CHECK FAILED: the narrow build differs outside prompt text")
    $n = [Math]::Min($la.Count, $lb.Count)
    for ($i = 0; $i -lt $n; $i++) {
        if ($la[$i] -ne $lb[$i]) { $bad.Add("   line $($i+1): '$($la[$i])' -> '$($lb[$i])'"); break }
    }
    if ($la.Count -ne $lb.Count) { $bad.Add("   line count $($la.Count) -> $($lb.Count)") }
}

$unused = $Short.Keys | Where-Object { -not $applied.ContainsKey($_) }
foreach ($u in $unused) { $bad.Add("stale rule: nothing in the template says '$u'") }

# --- report --------------------------------------------------------------------
"emailTo narrow build  ($([System.IO.Path]::GetFileName($Source)) -> $([System.IO.Path]::GetFileName($Out)))"
"  prose      {0,4} lines re-wrapped to {1} px -> {2} lines" -f $stats.prose, $ProsePx, $stats.wrapped
"  captions   {0,4} shortened to fit the {1} px label column" -f $stats.captions, $LabelPx
if ($bad.Count) {
    ""
    "OVER BUDGET at a 480 px prompt sheet ($($bad.Count)):"
    $bad | ForEach-Object { "  $_" }
    ""
    "Add a short form to `$Short in this script, or shorten the text in emailTo.tpl."
    exit 1
}
"  checked    every line fits the {0} px client area with headroom" -f $ClientPx

if ($Check) { "  (check only - nothing written)"; exit 0 }

[System.IO.File]::WriteAllBytes($Out, $enc.GetBytes(($doc -join "`r`n")))
"  written    $Out"
exit 0
