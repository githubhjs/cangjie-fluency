<#
  cangjie5_fluency one-click installer for Weasel (Rime for Windows), Windows 10/11.

  Run as a NORMAL user. Only installing Weasel itself needs admin (UAC prompt appears).

  One line (PowerShell):
    irm https://raw.githubusercontent.com/githubhjs/cangjie-fluency/main/install.ps1 | iex
  Or from a downloaded release folder: double-click install.bat

  Options:  -SkipWeaselInstall  do not try to install Weasel (it must already be installed)
            -NoDeploy           copy files only, do not run WeaselDeployer
            -NoModel            do not download the 41 MB language model (sentence correction is weaker)
            -Cangjie5           also install the 5th-generation schema cangjie5_fluency
            -NoCangjie3         do NOT install the 3rd-generation schema (then the 5th generation is installed)
            -WithV2             also install the experimental cangjie5_fluency_v2 schema (implies -Cangjie5)
            -Cangjie3           accepted for compatibility; the 3rd generation is now installed by default

  DEFAULT = 3rd-generation Cangjie (cangjie3_fluency, the table behind Windows XP's new Cangjie). Its table
  (mscj3.cin, kept unchanged in this repository under tables/, SHA-256 checked) is converted here into
  cangjie3.base.dict.yaml. cangjie3_fluency is listed FIRST in default.custom.yaml.
            -DryRun             print what would be done, change nothing
            -Ref <branch|tag>   which version of the schema files to download (default: main)
            -RimeDir <path>     user folder (default: Weasel's RimeUserDir or %APPDATA%\Rime)
            -WeaselDir <path>   Weasel program folder (default: auto-detect under Program Files)

  Everything this script writes is in the Rime user folder. Existing files are backed up as *.bak-<time>.
#>
param(
  [switch]$SkipWeaselInstall,
  [switch]$NoDeploy,
  [switch]$NoModel,
  [switch]$WithV2,
  [switch]$Cangjie3,
  [switch]$Cangjie5,
  [switch]$NoCangjie3,
  [switch]$DryRun,
  [string]$Ref = 'main',
  [string]$RimeDir = '',
  [string]$WeaselDir = ''
)

# Everything runs inside a script block (own scope) so that, when started with  irm ... | iex,
# no variable or $ErrorActionPreference leaks into the user's session and an error never closes the window.
try { & {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$Repo     = 'githubhjs/cangjie-fluency'
$SchemaRaw = "https://raw.githubusercontent.com/$Repo/$Ref/weasel"
$BaseDictUrl = 'https://raw.githubusercontent.com/rime/rime-cangjie/master/cangjie5.base.dict.yaml'
$EssayUrl    = 'https://raw.githubusercontent.com/rime/rime-essay/master/essay.txt'
$GramUrl     = 'https://github.com/lotem/rime-octagram-data/raw/hant/zh-hant-t-essay-bgw.gram'
$GramSize    = 41415724
$Cin3Url      = "https://raw.githubusercontent.com/githubhjs/cangjie-fluency/$Ref/tables/mscj3.cin"
$Cin3Fallback = 'https://raw.githubusercontent.com/EasyIME/PIME/e6e4529ed69dea11171365054b8134f5866fe33f/python/cinbase/cin/mscj3.cin'
$Cin3Sha256   = 'a7b3d03898dc0b2b0bd7803ad0be7b940a1ed945ac5d6314ed832b1dbf6839a2'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$do3 = -not $NoCangjie3                                  # 3rd generation is the default
$do5 = [bool]($Cangjie5 -or $WithV2 -or $NoCangjie3)     # 5th generation only when asked for (or when 3rd is declined)

function Say($m)  { Write-Host "[cangjie-fluency] $m" }
function Warn($m) { Write-Host "[cangjie-fluency] WARNING: $m" -ForegroundColor Yellow }
function Fail($m) { throw $m }   # caught at the bottom; never use exit (it would close the user's PowerShell under iex)

function Write-Utf8NoBom($path, $text) {
  [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}

function Backup-IfExists($path) {
  if (Test-Path $path) {
    $bak = "$path.bak-$Stamp"
    if ($DryRun) { Say "DRY: would back up $path -> $bak" } else { Copy-Item $path $bak; Say "backed up $path -> $bak" }
  }
}

# SHA-256 through .NET: does not depend on the Microsoft.PowerShell.Utility module, which Windows PowerShell 5.1
# cannot find when it was started from a PowerShell 7 window (it inherits pwsh's PSModulePath).
function Get-Sha256($path) {
  $sha = [Security.Cryptography.SHA256]::Create()
  $fs = [IO.File]::OpenRead($path)
  try { return [BitConverter]::ToString($sha.ComputeHash($fs)) } finally { $fs.Dispose(); $sha.Dispose() }
}

function Same-Content($a, $b) {
  if (-not (Test-Path $b)) { return $false }
  return ((Get-Sha256 $a) -eq (Get-Sha256 $b))
}

# Put the finished temp file in place. Identical content = nothing to do (no backup, no overwrite).
function Place-File($tmp, $dest) {
  $leaf = Split-Path $dest -Leaf
  try {
    if (Same-Content $tmp $dest) { Remove-Item $tmp -Force; Say "up to date: $leaf"; return }
    if (Test-Path $dest) { Backup-IfExists $dest; Remove-Item $dest -Force }
    Move-Item $tmp $dest
    Say "installed: $leaf"
  } catch {
    if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }   # never leave a *.part behind
    throw
  }
}

# .cin -> Rime dict (cangjie3.base). MUST stay byte-identical to tools/cin2rime.py output.
function Convert-CinToRime($cinPath, $outPath, $essayPath) {
  $enc = New-Object Text.UTF8Encoding($false)
  $lines = [IO.File]::ReadAllLines($cinPath, $enc)
  # essay.txt single-character frequencies keep word-frequency information in the weights
  # (same rule as tools/cin2rime.py --essay); without essay.txt weights are 100000 - rank
  $freq = $null
  if ($essayPath -and (Test-Path $essayPath)) {
    $freq = New-Object 'System.Collections.Generic.Dictionary[string,long]'
    foreach ($el in [IO.File]::ReadAllLines($essayPath, $enc)) {
      $ep = $el.Split([char]9)
      if ($ep.Length -ne 2) { continue }
      $et = $ep[0]
      if (-not (($et.Length -eq 1) -or ($et.Length -eq 2 -and [char]::IsHighSurrogate($et[0]) -and [char]::IsLowSurrogate($et[1])))) { continue }
      if ($ep[1] -notmatch '^[0-9]+$') { continue }
      $freq[$et] = [long]$ep[1]
    }
  }
  $prevw = New-Object 'System.Collections.Generic.Dictionary[string,long]'
  $sb = New-Object System.Text.StringBuilder
  $hdr = "# encoding: utf-8`n# Generated by tools/cin2rime.py from a .cin table. Do not commit this file.`n`n---`nname: cangjie3.base`nversion: `"1.0`"`nsort: by_weight`ncolumns:`n  - text`n  - code`n  - weight`n...`n`n"
  [void]$sb.Append($hdr)
  $seen = New-Object 'System.Collections.Generic.HashSet[string]'
  $rank = New-Object 'System.Collections.Generic.Dictionary[string,int]'
  $trim = [char[]]@(' ', [char]9, [char]13)
  $inDef = $false
  $written = 0; $multi = 0; $dup = 0
  foreach ($raw in $lines) {
    $line = $raw.Trim($trim)
    if ($line.Length -eq 0) { continue }
    if ($line.StartsWith('%')) {
      $low = [regex]::Split($line.ToLowerInvariant(), '[ \t]+')
      if ($low[0] -eq '%chardef' -and $low.Length -gt 1) { $inDef = ($low[1] -eq 'begin') }
      continue
    }
    if (-not $inDef) { continue }
    $parts = [regex]::Split($line, '[ \t]+')
    if ($parts.Length -lt 2) { continue }
    $code = $parts[0].ToLowerInvariant(); $text = $parts[1]
    $single = ($text.Length -eq 1) -or ($text.Length -eq 2 -and [char]::IsHighSurrogate($text[0]) -and [char]::IsLowSurrogate($text[1]))
    if (-not $single) { $multi++; continue }
    if (-not $seen.Add($text + [char]9 + $code)) { $dup++; continue }
    $r = 0
    if ($rank.ContainsKey($code)) { $r = $rank[$code] }
    $rank[$code] = $r + 1
    [long]$w = 100000 - $r
    if ($freq -ne $null) {
      $w = 1
      if ($freq.ContainsKey($text) -and $freq[$text] -gt 1) { $w = $freq[$text] }
      if ($prevw.ContainsKey($code) -and ($prevw[$code] - 1) -lt $w) { $w = $prevw[$code] - 1 }
      if ($w -lt 1) { $w = 1 }
      $prevw[$code] = $w
    }
    [void]$sb.Append($text).Append([char]9).Append($code).Append([char]9).Append($w.ToString([Globalization.CultureInfo]::InvariantCulture)).Append([char]10)
    $written++
  }
  [IO.File]::WriteAllText($outPath, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
  Say "converted table: $written entries ($multi multi-character skipped, $dup duplicates skipped)"
}

function Get-Remote($url, $dest, $minBytes, $exactBytes) {
  if ($DryRun) { Say "DRY: would download $url -> $dest"; return }
  $tmp = "$dest.part"
  Say "downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
  $len = (Get-Item $tmp).Length
  if ($exactBytes -gt 0 -and $len -ne $exactBytes) { Remove-Item $tmp -Force; Fail "$dest has $len bytes, expected $exactBytes" }
  if ($len -lt $minBytes) { Remove-Item $tmp -Force; Fail "$dest is only $len bytes, the download looks wrong" }
  Place-File $tmp $dest
}

function Find-Weasel {
  if ($WeaselDir -ne '') { if (Test-Path (Join-Path $WeaselDir 'WeaselDeployer.exe')) { return $WeaselDir } else { return $null } }
  $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
  $cands = @()
  foreach ($r in $roots) {
    $rime = Join-Path $r 'Rime'
    if (Test-Path $rime) {
      $cands += Get-ChildItem $rime -Directory -Filter 'weasel-*' -ErrorAction SilentlyContinue |
                Where-Object { Test-Path (Join-Path $_.FullName 'WeaselDeployer.exe') }
    }
  }
  if ($cands.Count -eq 0) { return $null }
  return ($cands | Sort-Object Name -Descending | Select-Object -First 1).FullName
}

# ---------- 1. Weasel ----------
$weasel = Find-Weasel
if (-not $weasel) {
  if ($SkipWeaselInstall) { Fail 'Weasel is not installed (WeaselDeployer.exe not found). Install it from https://github.com/rime/weasel/releases and run this again.' }
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($DryRun) { Say 'DRY: Weasel not found; would run: winget install --id Rime.Weasel -e' }
  elseif ($winget) {
    Say 'Weasel not found. Installing with winget (a UAC prompt will appear; accept it)...'
    & winget install --id Rime.Weasel -e --accept-package-agreements --accept-source-agreements
    $weasel = Find-Weasel
    if (-not $weasel) { Fail 'winget finished but Weasel was not found. Install it manually from https://github.com/rime/weasel/releases then run this script again.' }
  } else {
    Fail 'Weasel is not installed and winget is not available. Download weasel-*-installer.exe from https://github.com/rime/weasel/releases, run it (admin), then run this script again.'
  }
}
if ($weasel) { Say "Weasel found: $weasel" } else { Say 'DRY: continuing without a Weasel folder.' }
$dataDir = ''
if ($weasel) { $dataDir = Join-Path $weasel 'data' }

# ---------- 2. Rime user folder ----------
if ($RimeDir -eq '') {
  $reg = $null
  try { $reg = (Get-ItemProperty 'HKCU:\Software\Rime\Weasel' -ErrorAction Stop).RimeUserDir } catch { }
  if ($reg) { $RimeDir = $reg } else { $RimeDir = Join-Path $env:APPDATA 'Rime' }
}
Say "Rime user folder: $RimeDir"
if (-not (Test-Path $RimeDir)) { if ($DryRun) { Say "DRY: would create $RimeDir" } else { New-Item -ItemType Directory -Path $RimeDir | Out-Null } }

# ---------- 3. schema files (local copy next to this script, else download) ----------
$here = $PSScriptRoot
$schemaFiles = @()
if ($do5) { $schemaFiles += @('cangjie5_fluency.schema.yaml', 'cangjie5_fluency.dict.yaml') }
if ($WithV2) { $schemaFiles += 'cangjie5_fluency_v2.schema.yaml' }
if ($do3) { $schemaFiles += @('cangjie3_fluency.schema.yaml', 'cangjie3_fluency.dict.yaml') }
foreach ($f in $schemaFiles) {
  $dest = Join-Path $RimeDir $f
  $local = $null
  if ($here) {
    foreach ($c in @((Join-Path $here $f), (Join-Path (Join-Path $here 'weasel') $f))) { if (Test-Path $c) { $local = $c; break } }
  }
  if ($local) {
    if ($DryRun) { Say "DRY: would copy $local -> $dest" }
    else { $tmp = "$dest.part"; Copy-Item $local $tmp -Force; Place-File $tmp $dest }
  } else {
    Get-Remote "$SchemaRaw/$f" $dest 500 0
  }
}

# ---------- 4. code table, word list, language model ----------
if ($do5) {
  $base = Join-Path $RimeDir 'cangjie5.base.dict.yaml'
  $haveBase = (Test-Path $base) -or ($dataDir -and (Test-Path (Join-Path $dataDir 'cangjie5.base.dict.yaml')))
  if ($haveBase) { Say 'cangjie5.base.dict.yaml already present.' } else { Get-Remote $BaseDictUrl $base 100000 0 }
}

$essay = Join-Path $RimeDir 'essay.txt'
$haveEssay = (Test-Path $essay) -or ($dataDir -and (Test-Path (Join-Path $dataDir 'essay.txt')))
if ($haveEssay) { Say 'essay.txt already present.' } else { Get-Remote $EssayUrl $essay 1000000 0 }

if ($dataDir -and -not (Test-Path (Join-Path $dataDir 'luna_quanpin.schema.yaml')) -and -not (Test-Path (Join-Path $RimeDir 'luna_quanpin.schema.yaml'))) {
  Warn 'luna_quanpin.schema.yaml not found in Weasel data; pinyin reverse lookup may fail to compile. Install rime-luna-pinyin or update Weasel.'
}

if ($do3) {
  $base3 = Join-Path $RimeDir 'cangjie3.base.dict.yaml'
  if ($DryRun) { Say "DRY: would download $Cin3Url, convert it and install cangjie3.base.dict.yaml" }
  else {
    $cinTmp = Join-Path ([IO.Path]::GetTempPath()) ('mscj3-' + $Stamp + '.cin')
    $localCin = $null
    if ($here) {
      foreach ($c in @((Join-Path (Join-Path $here 'tables') 'mscj3.cin'), (Join-Path $here 'mscj3.cin'))) { if (Test-Path $c) { $localCin = $c; break } }
    }
    if ($localCin) { Copy-Item $localCin $cinTmp -Force; Say "using $localCin" }
    else {
      Say "downloading $Cin3Url"
      try { Invoke-WebRequest -Uri $Cin3Url -OutFile $cinTmp -UseBasicParsing }
      catch {
        Warn "repo copy not available ($($_.Exception.Message)); using the pinned PIME copy instead"
        Invoke-WebRequest -Uri $Cin3Fallback -OutFile $cinTmp -UseBasicParsing
      }
    }
    $cinLen = (Get-Item $cinTmp).Length
    if ($cinLen -lt 100000) { Remove-Item $cinTmp -Force; Fail "mscj3.cin is only $cinLen bytes, the download looks wrong" }
    $cinSha = ((Get-Sha256 $cinTmp) -replace '-', '').ToLower()
    if ($cinSha -ne $Cin3Sha256) { Remove-Item $cinTmp -Force; Fail "mscj3.cin SHA-256 is $cinSha, expected $Cin3Sha256" }
    $tmp3 = "$base3.part"
    $essayFor3 = $null
    if (Test-Path $essay) { $essayFor3 = $essay } elseif ($dataDir -and (Test-Path (Join-Path $dataDir 'essay.txt'))) { $essayFor3 = Join-Path $dataDir 'essay.txt' }
    if (-not $essayFor3) { Warn 'essay.txt not found; cangjie3 weights fall back to .cin order only (weaker sentence correction).' }
    Convert-CinToRime $cinTmp $tmp3 $essayFor3
    Remove-Item $cinTmp -Force
    Place-File $tmp3 $base3
  }
}

$gram = Join-Path $RimeDir 'zh-hant-t-essay-bgw.gram'
if ($NoModel) { Say 'skipping language model (-NoModel).' }
elseif ((Test-Path $gram) -and ((Get-Item $gram).Length -eq $GramSize)) { Say 'language model already present.' }
else { Get-Remote $GramUrl $gram 1000000 $GramSize }

# ---------- 5. default.custom.yaml ----------
$dc = Join-Path $RimeDir 'default.custom.yaml'
$ids = @()
if ($do3) { $ids += 'cangjie3_fluency' }
if ($do5) { $ids += 'cangjie5_fluency' }
if ($WithV2) { $ids += 'cangjie5_fluency_v2' }

# A patched schema_list REPLACES Weasel's stock list, so keep the stock schemas: read them from Weasel's own default.yaml.
function Get-StockSchemaIds {
  $out = @()
  $f = $null
  if ($dataDir) { $f = Join-Path $dataDir 'default.yaml' }
  if ($f -and (Test-Path $f)) {
    $in = $false
    foreach ($line in [IO.File]::ReadAllLines($f)) {
      if ($line -match '^schema_list:\s*(#.*)?$') { $in = $true; continue }
      if ($in) {
        if ($line -match '^\s*-\s*\{?\s*schema:\s*([A-Za-z0-9_]+)') { $out += $Matches[1]; continue }
        if ($line -match '^\S' -and $line -notmatch '^\s*#') { break }
      }
    }
  }
  if ($out.Count -eq 0) { $out = @('cangjie5', 'luna_pinyin') }
  return $out
}
$stock = @(Get-StockSchemaIds | Where-Object { $ids -notcontains $_ })
$listBody = @()
foreach ($id in $ids) { $listBody += $id }
foreach ($id in $stock) { $listBody += $id }

if (-not (Test-Path $dc)) {
  $freshLines = @('# encoding: utf-8', '# created by cangjie-fluency install.ps1', 'patch:', '  schema_list:')
  foreach ($id in $listBody) { $freshLines += "    - schema: $id" }
  $freshCrlf = ($freshLines -join "`r`n") + "`r`n"
  if ($DryRun) { Say "DRY: would create $dc" } else { Write-Utf8NoBom $dc $freshCrlf; Say 'created default.custom.yaml' }
} else {
  $txt = [IO.File]::ReadAllText($dc)
  # exact id match, so cangjie5_fluency is not confused with cangjie5_fluency_v2
  $missing = @($ids | Where-Object { $txt -notmatch ([regex]::Escape($_) + '(?![A-Za-z0-9_])') })
  if ($missing.Count -eq 0) {
    Say 'default.custom.yaml already lists everything needed.'
  } else {
    $lines = $txt -split "`r?`n"
    $idx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^(\s*)schema_list:\s*(#.*)?$') { $idx = $i; break } }
    if ($idx -ge 0) {
      $indent = ([regex]::Match($lines[$idx], '^(\s*)')).Groups[1].Value + '  '
      for ($j = $idx + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j].Trim() -eq '') { continue }
        if ($lines[$j] -match '^(\s*)-\s') { $indent = ([regex]::Match($lines[$j], '^(\s*)')).Groups[1].Value }
        break
      }
      $new = @()
      for ($i = 0; $i -lt $lines.Count; $i++) {
        $new += $lines[$i]
        if ($i -eq $idx) { foreach ($id in $missing) { if ($id -ne 'cangjie5_fluency_v2') { $new += ($indent + '- schema: ' + $id) } } }
      }
      if ($missing -contains 'cangjie5_fluency_v2') {
        # the experimental schema goes right after v1 when v1 is listed, so it never becomes the default
        $at = -1
        for ($k = 0; $k -lt $new.Count; $k++) { if ($new[$k] -match 'schema:\s*cangjie5_fluency(?![A-Za-z0-9_])') { $at = $k; break } }
        if ($at -lt 0) { $at = $idx }
        $head = @($new[0..$at]); $tail = @()
        if ($at + 1 -lt $new.Count) { $tail = @($new[($at + 1)..($new.Count - 1)]) }
        $new = $head + @($indent + '- schema: cangjie5_fluency_v2') + $tail
      }
      Backup-IfExists $dc
      if ($DryRun) { Say "DRY: would add $($missing -join ', ') to schema_list in $dc" }
      else { Write-Utf8NoBom $dc (($new -join "`r`n")); Say "added $($missing -join ', ') to the schema_list in your default.custom.yaml" }
    } else {
      # No schema_list yet (for example the file Weasel's installer leaves behind). Add one under `patch:` with ours first
      # and Weasel's stock schemas after, so nothing the user had is lost.
      $block = @('  schema_list:')
      foreach ($id in $listBody) { $block += "    - schema: $id" }
      $pi = -1
      for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^patch:\s*(#.*)?$|^patch:\s*(\{\s*\}|~|null)\s*(#.*)?$') { $pi = $i; break } }
      $hasPatchKey = $false
      foreach ($l in $lines) { if ($l -match '^patch:') { $hasPatchKey = $true; break } }
      $new = $null
      if ($pi -ge 0) {
        $new = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
          if ($i -eq $pi) { $new += 'patch:'; $new += $block } else { $new += $lines[$i] }
        }
      } elseif (-not $hasPatchKey) {
        $new = @($lines | Where-Object { $true })
        # drop trailing blank lines (an empty or blank-only file must end up empty; note 0..-1 in PowerShell is the two-element range 0,-1)
        $keep = $new.Count
        while ($keep -gt 0 -and $new[$keep - 1].Trim() -eq '') { $keep-- }
        if ($keep -gt 0) { $new = @($new[0..($keep - 1)]) } else { $new = @() }
        $new += 'patch:'; $new += $block
      }
      if ($new) {
        Backup-IfExists $dc
        if ($DryRun) { Say "DRY: would add a schema_list ($($listBody -join ', ')) to $dc" }
        else { Write-Utf8NoBom $dc (($new -join "`r`n") + "`r`n"); Say "added a schema_list to your default.custom.yaml: $($listBody -join ', ')" }
      } else {
        Warn "Your default.custom.yaml has a non-standard 'patch:' (inline mapping), so I did not edit it. Add this under 'patch:' yourself:"
        Write-Host "  schema_list:"
        foreach ($id in $listBody) { Write-Host "    - schema: $id" }
      }
    }
  }
}

# ---------- 6. deploy ----------
if ($NoDeploy -or $DryRun -or -not $weasel) {
  Say 'skipping deploy. Run later: Start menu > Weasel > Redeploy'
} else {
  Say 'deploying (takes about 30 seconds on first run)...'
  # Process.Start with a plain argument string: Windows PowerShell 5.1's Start-Process -ArgumentList '/deploy' sent "/deploy "
  # (trailing space), which WeaselDeployer does not recognise, so it opened the schema/theme wizard and waited for the user.
  $p = [Diagnostics.Process]::Start((Join-Path $weasel 'WeaselDeployer.exe'), '/deploy')
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) { Warn "WeaselDeployer exit code $($p.ExitCode). Look at %TEMP%\rime.weasel\ for ERROR logs." } else { Say 'deploy finished.' }
}

# ---------- 7. what next ----------
Write-Host ''
Say 'Done. Next steps:'
if ($do3) {
  Write-Host '  1. Press Ctrl+` (or F4) in any text box and choose the schema "cangjie3_fluency" (3rd-generation sentence-style Cangjie, listed first).'
  Write-Host '  2. Type dhedhkb  (should become the two characters for Banqiao as you type the last code); mwyl gives the character for "face".'
} else {
  Write-Host '  1. Press Ctrl+` (or F4) in any text box and choose the schema "cangjie5_fluency" (5th-generation sentence-style Cangjie).'
  Write-Host '  2. Type dhedhkb  (should become the two characters for Banqiao as you type the last code).'
}
Write-Host '  3. Check the language model loaded (after you typed once with the schema):'
Write-Host '       Select-String -Path "$env:TEMP\rime.weasel\*.log" -Pattern "use grammar|failed to load grammar" | Select -Last 5'
Write-Host '     Loaded = a "use grammar" line and NO "failed to load grammar database" line after it.'
Write-Host '     (The "use grammar" line is also printed when the .gram file is missing; the failure line is what tells them apart.)'
} } catch {
  Write-Host "[cangjie-fluency] ERROR: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host '[cangjie-fluency] Stopped. Files written before this point are kept (existing ones were backed up as *.bak-<time>).' -ForegroundColor Red
}
