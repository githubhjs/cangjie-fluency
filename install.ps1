<#
  cangjie5_fluency one-click installer for Weasel (Rime for Windows), Windows 10/11.

  Run as a NORMAL user. Only installing Weasel itself needs admin (UAC prompt appears).

  One line (PowerShell):
    irm https://raw.githubusercontent.com/githubhjs/cangjie-fluency/main/install.ps1 | iex
  Or from a downloaded release folder: double-click install.bat

  Options:  -SkipWeaselInstall  do not try to install Weasel (it must already be installed)
            -NoDeploy           copy files only, do not run WeaselDeployer
            -NoModel            do not download the 41 MB language model (sentence correction is weaker)
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
  [switch]$DryRun,
  [string]$Ref = 'main',
  [string]$RimeDir = '',
  [string]$WeaselDir = ''
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

$Repo     = 'githubhjs/cangjie-fluency'
$SchemaRaw = "https://raw.githubusercontent.com/$Repo/$Ref/weasel"
$BaseDictUrl = 'https://raw.githubusercontent.com/rime/rime-cangjie/master/cangjie5.base.dict.yaml'
$EssayUrl    = 'https://raw.githubusercontent.com/rime/rime-essay/master/essay.txt'
$GramUrl     = 'https://github.com/lotem/rime-octagram-data/raw/hant/zh-hant-t-essay-bgw.gram'
$GramSize    = 41415724
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$NeedRelogin = $false

function Say($m)  { Write-Host "[cangjie-fluency] $m" }
function Warn($m) { Write-Host "[cangjie-fluency] WARNING: $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[cangjie-fluency] ERROR: $m" -ForegroundColor Red; exit 1 }

function Write-Utf8NoBom($path, $text) {
  [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}

function Backup-IfExists($path) {
  if (Test-Path $path) {
    $bak = "$path.bak-$Stamp"
    if ($DryRun) { Say "DRY: would back up $path -> $bak" } else { Copy-Item $path $bak; Say "backed up $path -> $bak" }
  }
}

function Get-Remote($url, $dest, $minBytes, $exactBytes) {
  if ($DryRun) { Say "DRY: would download $url -> $dest"; return }
  $tmp = "$dest.part"
  Say "downloading $url"
  Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
  $len = (Get-Item $tmp).Length
  if ($exactBytes -gt 0 -and $len -ne $exactBytes) { Remove-Item $tmp -Force; Fail "$dest has $len bytes, expected $exactBytes" }
  if ($len -lt $minBytes) { Remove-Item $tmp -Force; Fail "$dest is only $len bytes, the download looks wrong" }
  if (Test-Path $dest) { Remove-Item $dest -Force }
  Move-Item $tmp $dest
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
    $NeedRelogin = $true
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
foreach ($f in @('cangjie5_fluency.schema.yaml', 'cangjie5_fluency.dict.yaml')) {
  $dest = Join-Path $RimeDir $f
  $local = $null
  if ($here) {
    foreach ($c in @((Join-Path $here $f), (Join-Path (Join-Path $here 'weasel') $f))) { if (Test-Path $c) { $local = $c; break } }
  }
  if (Test-Path $dest) { Backup-IfExists $dest }
  if ($local) {
    if ($DryRun) { Say "DRY: would copy $local -> $dest" } else { Copy-Item $local $dest -Force; Say "copied $f" }
  } else {
    Get-Remote "$SchemaRaw/$f" $dest 500 0
  }
}

# ---------- 4. code table, word list, language model ----------
$base = Join-Path $RimeDir 'cangjie5.base.dict.yaml'
$haveBase = (Test-Path $base) -or ($dataDir -and (Test-Path (Join-Path $dataDir 'cangjie5.base.dict.yaml')))
if ($haveBase) { Say 'cangjie5.base.dict.yaml already present.' } else { Get-Remote $BaseDictUrl $base 100000 0 }

$essay = Join-Path $RimeDir 'essay.txt'
$haveEssay = (Test-Path $essay) -or ($dataDir -and (Test-Path (Join-Path $dataDir 'essay.txt')))
if ($haveEssay) { Say 'essay.txt already present.' } else { Get-Remote $EssayUrl $essay 1000000 0 }

if ($dataDir -and -not (Test-Path (Join-Path $dataDir 'luna_quanpin.schema.yaml')) -and -not (Test-Path (Join-Path $RimeDir 'luna_quanpin.schema.yaml'))) {
  Warn 'luna_quanpin.schema.yaml not found in Weasel data; pinyin reverse lookup may fail to compile. Install rime-luna-pinyin or update Weasel.'
}

$gram = Join-Path $RimeDir 'zh-hant-t-essay-bgw.gram'
if ($NoModel) { Say 'skipping language model (-NoModel).' }
elseif ((Test-Path $gram) -and ((Get-Item $gram).Length -eq $GramSize)) { Say 'language model already present.' }
else { Get-Remote $GramUrl $gram 1000000 $GramSize }

# ---------- 5. default.custom.yaml ----------
$dc = Join-Path $RimeDir 'default.custom.yaml'
$entry = 'cangjie5_fluency'
$fresh = @"
# encoding: utf-8
# created by cangjie-fluency install.ps1
patch:
  schema_list:
    - schema: cangjie5_fluency
    - schema: cangjie5
    - schema: luna_pinyin
"@
if (-not (Test-Path $dc)) {
  if ($DryRun) { Say "DRY: would create $dc" } else { Write-Utf8NoBom $dc ($fresh + "`r`n"); Say 'created default.custom.yaml' }
} else {
  $txt = [IO.File]::ReadAllText($dc)
  if ($txt -match 'cangjie5_fluency') {
    Say 'default.custom.yaml already lists cangjie5_fluency.'
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
        if ($i -eq $idx) { $new += ($indent + '- schema: cangjie5_fluency') }
      }
      Backup-IfExists $dc
      if ($DryRun) { Say "DRY: would add '- schema: cangjie5_fluency' to schema_list in $dc" }
      else { Write-Utf8NoBom $dc (($new -join "`r`n")); Say 'added cangjie5_fluency to the schema_list in your default.custom.yaml (first position)' }
    } else {
      Warn "Your default.custom.yaml has no schema_list, so I did not edit it. Add this under 'patch:' yourself:"
      Write-Host "  schema_list:"
      Write-Host "    - schema: cangjie5_fluency"
      Write-Host "    - schema: cangjie5"
      Write-Host "    - schema: luna_pinyin"
    }
  }
}

# ---------- 6. deploy ----------
if ($NoDeploy -or $DryRun -or -not $weasel) {
  Say 'skipping deploy. Run later: Start menu > Weasel > Redeploy'
} else {
  Say 'deploying (takes about 30 seconds on first run)...'
  $p = Start-Process -FilePath (Join-Path $weasel 'WeaselDeployer.exe') -ArgumentList '/deploy' -Wait -PassThru
  if ($p.ExitCode -ne 0) { Warn "WeaselDeployer exit code $($p.ExitCode). Look at %TEMP%\rime.weasel\ for ERROR logs." } else { Say 'deploy finished.' }
}

# ---------- 7. what next ----------
Write-Host ''
Say 'Done. Next steps:'
Write-Host '  1. Press Ctrl+` (or F4) in any text box and choose the schema "cangjie5_fluency" (shown as the sentence-style Cangjie).'
Write-Host '  2. Type dhedhkb  (should become the two characters for Banqiao as you type the last code).'
Write-Host '  3. Check the language model loaded (after you typed once with the schema):'
Write-Host '       Select-String -Path "$env:TEMP\rime.weasel\*.log" -Pattern "use grammar" | Select -Last 3'
Write-Host '     No "use grammar" line = the model is not loaded (schema still works).'
if ($NeedRelogin) { Warn 'Weasel was just installed or upgraded: sign out and sign in again (or restart) before typing, otherwise apps that were already open can crash on first use.' }
