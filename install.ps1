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
            -NoSweep            do NOT install the Sweep Pad (cangjie-sweep)
            -PadRef <tag>       which version of Sweep Pad to install (default: v0.4.1)
            -Uninstall          remove Sweep Pad files and Start Menu shortcut

  DEFAULT = 3rd-generation Cangjie (cangjie3_fluency, the table behind Windows XP's new Cangjie). Its table
  (mscj3.cin, kept unchanged in this repository under tables/, SHA-256 checked) is converted here into
  cangjie3.base.dict.yaml. cangjie3_fluency is listed FIRST in default.custom.yaml.
            -Offline            never use the network: everything must be next to this script (full release zip)
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
  [switch]$NoFuzzy,
  [switch]$FuzzyDefault,
  [ValidateSet('narrow', 'normal', 'wide')][string]$FuzzyRange = 'normal',
  [switch]$NoSweep,
  [string]$PadRef = 'v0.4.1',
  [switch]$Uninstall,
  [switch]$Offline,
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
$RepoRaw = "https://raw.githubusercontent.com/$Repo/$Ref"
$DepsUrl = "https://github.com/$Repo/releases/download/deps-v1"
$here = $PSScriptRoot
$WeaselInstaller = 'weasel-0.17.4.0-installer.exe'
$WeaselSha   = 'cf509534a8f5f8af9c98ed7cbb8f135439f145a8cbe7e50ede42bb5b5ab45c29'
$BaseDictUrl = "$RepoRaw/tables/cangjie5.base.dict.yaml"
$BaseDictSha = '0b7a801720bbf04cea06c55577c159e2e67b9bbb763bf00026a8520497772799'
$EssayUrl    = "$RepoRaw/data/essay.txt"
$EssaySha    = '3e8512ebaa6657e35961b1f5762060717c647e3bf471d5e3b86e783b4e934ffb'
$GramUrl     = "$RepoRaw/data/zh-hant-t-essay-bgw.gram"
$GramSha     = '0488ebd6688f900a39200f2b794f2f99bcbf1e8fc27280ae4a2324b08b1559c1'
$GramSize    = 41415724
$Cin3Url     = "$RepoRaw/tables/mscj3.cin"
$Cin3Sha256  = 'a7b3d03898dc0b2b0bd7803ad0be7b940a1ed945ac5d6314ed832b1dbf6839a2'
$PadRepo     = 'githubhjs/cangjie-fuzzy-core'
if (-not $PadRef) { $PadRef = 'v0.4.1' }
$PadZipName  = "cangjie-sweep-pad-$PadRef.zip"
$PadUrl      = "https://github.com/$PadRepo/releases/download/$PadRef/$PadZipName"
$PadShaUrl   = "$PadUrl.sha256"
$localAppData = $env:LOCALAPPDATA
if (-not $localAppData) {
  $localAppData = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } elseif ($env:HOME) { Join-Path $env:HOME '.local/share' } else { [IO.Path]::GetTempPath() }
}
$sweepDir = Join-Path $localAppData 'cangjie-sweep'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$do3 = -not $NoCangjie3                                  # 3rd generation is the default
$do5 = [bool]($Cangjie5 -or $WithV2 -or $NoCangjie3)     # 5th generation only when asked for (or when 3rd is declined)

function Say($m)  { Write-Host "[cangjie-fluency] $m" }
function Zh($m) { Write-Host ('                  ' + [regex]::Unescape($m)) }
function U($m) { return [regex]::Unescape($m) }
function ZhL($m) { Write-Host ('                  ' + $m) }
function ZhW($m) { Write-Host ('                  ' + $m) -ForegroundColor Yellow }
function Warn($m) { Write-Host "[cangjie-fluency] WARNING: $m" -ForegroundColor Yellow }
function Fail($m, $zh = '') { $ex = New-Object System.Exception $m; if ($zh) { $ex.Data['zh'] = $zh }; throw $ex }   # caught at the bottom; never use exit (it would close the user's PowerShell under iex)

if ($Uninstall) {
  Say 'Uninstalling Sweep Pad...'
  ZhL (U '\u6b63\u5728\u79fb\u9664\u5009\u9821\u6ed1\u884c\u9762\u677f...')
  $programsDir = [Environment]::GetFolderPath('Programs')
  if (-not $programsDir -and $env:APPDATA) { $programsDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs' }
  $scName = (U 'Cangjie Sweep \u5009\u9821\u6ed1\u884c.lnk')
  $scPath = if ($programsDir) { Join-Path $programsDir $scName } else { $null }

  if ($DryRun) {
    if (Test-Path $sweepDir) { Say "DRY: would remove directory $sweepDir"; ZhL ((U '\u9810\u8a08\u79fb\u9664\u8cc7\u6599\u593e\uff1a') + $sweepDir) }
    if ($scPath -and (Test-Path $scPath)) { Say "DRY: would remove shortcut $scPath"; ZhL ((U '\u9810\u8a08\u79fb\u9664\u6377\u5f91\uff1a') + $scPath) }
  } else {
    if (Test-Path $sweepDir) {
      Remove-Item -Path $sweepDir -Recurse -Force
      Say "Removed directory: $sweepDir"
      ZhL ((U '\u5df2\u79fb\u9664\u8cc7\u6599\u593e\uff1a') + $sweepDir)
    }
    if ($scPath -and (Test-Path $scPath)) {
      Remove-Item -Path $scPath -Force
      Say "Removed shortcut: $scPath"
      ZhL ((U '\u5df2\u79fb\u9664\u6377\u5f91\uff1a') + $scPath)
    }
    Say 'Sweep Pad uninstalled.'
    ZhL (U '\u5009\u9821\u6ed1\u884c\u9762\u677f\u5df2\u79fb\u9664\u3002')
  }
  return
}

function Write-Utf8NoBom($path, $text) {
  [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
}

function Backup-IfExists($path) {
  if (Test-Path $path) {
    $bak = "$path.bak-$Stamp"
    if ($DryRun) { Say "DRY: would back up $path -> $bak"; ZhL ((U '\u9810\u8a08\u5099\u4efd\uff1a') + "$path -> $bak") } else { Copy-Item $path $bak; Say "backed up $path -> $bak"; ZhL ((U '\u5df2\u5099\u4efd\uff1a') + "$path -> $bak") }
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
    if (Same-Content $tmp $dest) { Remove-Item $tmp -Force; Say "up to date: $leaf"; ZhL ((U '\u5df2\u662f\u6700\u65b0\uff1a') + $leaf); return }
    if (Test-Path $dest) { Backup-IfExists $dest; Remove-Item $dest -Force }
    Move-Item $tmp $dest
    Say "installed: $leaf"; ZhL ((U '\u5df2\u5b89\u88dd\uff1a') + $leaf)
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
  ZhL ((U '\u5df2\u8f49\u63db\u78bc\u8868\uff1a') + $written + (U ' \u7b46\uff08\u7565\u904e\u591a\u5b57\u8a5e ') + $multi + (U ' \u7b46\u3001\u91cd\u8907 ') + $dup + (U ' \u7b46\uff09'))
}

function Get-Remote($url, $dest, $minBytes, $exactBytes) {
  if ($DryRun) { Say "DRY: would download $url -> $dest"; ZhL ((U '\u9810\u8a08\u4e0b\u8f09\uff1a') + "$url -> $dest"); return }
  $tmp = "$dest.part"
  Say "downloading $url"; ZhL ((U '\u4e0b\u8f09\u4e2d\uff1a') + $url)
  Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
  $len = (Get-Item $tmp).Length
  if ($exactBytes -gt 0 -and $len -ne $exactBytes) { Remove-Item $tmp -Force; Fail "$dest has $len bytes, expected $exactBytes" ($dest + (U ' \u7684\u5927\u5c0f\u662f ') + $len + (U ' \u4f4d\u5143\u7d44\uff0c\u9810\u671f\u70ba ') + $exactBytes + (U ' \u4f4d\u5143\u7d44')) }
  if ($len -lt $minBytes) { Remove-Item $tmp -Force; Fail "$dest is only $len bytes, the download looks wrong" ($dest + (U ' \u53ea\u6709 ') + $len + (U ' \u4f4d\u5143\u7d44\uff0c\u4e0b\u8f09\u5167\u5bb9\u4f3c\u4e4e\u4e0d\u6b63\u78ba')) }
  Place-File $tmp $dest
}

# Find a file shipped next to this script (full release zip layout: data\, tables\, weasel\, deps\) or flat next to it.
function Find-Local($rel) {
  if (-not $here) { return $null }
  $leaf = Split-Path $rel -Leaf
  foreach ($c in @((Join-Path $here $rel), (Join-Path $here $leaf))) { if (Test-Path $c) { return $c } }
  return $null
}

# Put a verified copy of a file in a temp path: local bundle first, else this repository (never a third party).
function Get-Staged($rel, $url, $sha, $minBytes) {
  $leaf = Split-Path $rel -Leaf
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("cjf-$Stamp-$leaf")
  $src = Find-Local $rel
  if ($src) { Copy-Item $src $tmp -Force; Say "using $src"; ZhL ((U '\u4f7f\u7528\u672c\u6a5f\u6a94\u6848\uff1a') + $src) }
  elseif ($Offline) { Fail "$leaf is not next to this script and -Offline was given" ($leaf + (U ' \u4e0d\u5728\u6b64\u8173\u672c\u65c1\u908a\uff0c\u800c\u4e14\u5df2\u6307\u5b9a -Offline')) }
  else { Say "downloading $url"; ZhL ((U '\u4e0b\u8f09\u4e2d\uff1a') + $url); Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing }
  $len = (Get-Item $tmp).Length
  if ($len -lt $minBytes) { Remove-Item $tmp -Force; Fail "$leaf is only $len bytes, the download looks wrong" ($leaf + (U ' \u53ea\u6709 ') + $len + (U ' \u4f4d\u5143\u7d44\uff0c\u4e0b\u8f09\u5167\u5bb9\u4f3c\u4e4e\u4e0d\u6b63\u78ba')) }
  if ($sha) {
    $got = ((Get-Sha256 $tmp) -replace '-', '').ToLower()
    if ($got -ne $sha) { Remove-Item $tmp -Force; Fail "$leaf SHA-256 is $got, expected $sha" ($leaf + (U ' \u7684 SHA-256 \u662f ') + $got + (U '\uff0c\u9810\u671f\u70ba ') + $sha) }
  }
  return $tmp
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
  if ($SkipWeaselInstall) { Fail 'Weasel is not installed (WeaselDeployer.exe not found). Run the installer that ships with this project (deps-v1 release) and run this again.' (U '\u627e\u4e0d\u5230 Weasel\uff08\u6c92\u6709 WeaselDeployer.exe\uff09\u3002\u8acb\u5148\u57f7\u884c\u672c\u5c08\u6848\u9644\u7684\u5b89\u88dd\u7a0b\u5f0f\uff08deps-v1 release\uff09\uff0c\u518d\u91cd\u65b0\u57f7\u884c\u672c\u8173\u672c\u3002') }
  if ($DryRun) { Say "DRY: Weasel not found; would install $WeaselInstaller (bundled or from $DepsUrl)"; ZhL ((U '\u9810\u8a08\uff1a\u627e\u4e0d\u5230 Weasel\uff0c\u5c07\u5b89\u88dd ') + $WeaselInstaller + (U '\uff08\u96a8\u9644\u6216\u5f9e ') + $DepsUrl + (U ' \u4e0b\u8f09\uff09')) }
  else {
    $inst = $null
    try { $inst = Get-Staged ("deps\" + $WeaselInstaller) ("$DepsUrl/$WeaselInstaller") $WeaselSha 5000000 } catch { Warn "Weasel installer from this project not available: $($_.Exception.Message)"; ZhW ((U '\u7121\u6cd5\u53d6\u5f97\u672c\u5c08\u6848\u7684 Weasel \u5b89\u88dd\u7a0b\u5f0f\uff1a') + $_.Exception.Message) }
    if ($inst) {
      Say 'Installing Weasel 0.17.4 from the project copy (a UAC prompt will appear; accept it)...'
      ZhL (U '\u6b63\u5728\u5f9e\u672c\u5c08\u6848\u63d0\u4f9b\u7684\u6a94\u6848\u5b89\u88dd Weasel 0.17.4\uff08\u6703\u8df3\u51fa UAC \u63d0\u793a\uff0c\u8acb\u6309\u300c\u662f\u300d\uff09...')
      try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $inst; $psi.Arguments = '/S'; $psi.UseShellExecute = $true; $psi.Verb = 'runas'
        $pr = [Diagnostics.Process]::Start($psi); $pr.WaitForExit()
      } catch { Warn "Weasel installer did not run: $($_.Exception.Message)"; ZhW ((U 'Weasel \u5b89\u88dd\u7a0b\u5f0f\u6c92\u6709\u57f7\u884c\uff1a') + $_.Exception.Message) }
      Remove-Item $inst -Force -ErrorAction SilentlyContinue
      $weasel = Find-Weasel
    }
    if (-not $weasel -and -not $Offline) {
      $winget = Get-Command winget -ErrorAction SilentlyContinue
      if ($winget) {
        Say 'Falling back to winget (a UAC prompt will appear; accept it)...'
        ZhL (U '\u6539\u7528 winget \u5b89\u88dd\uff08\u6703\u8df3\u51fa UAC \u63d0\u793a\uff0c\u8acb\u6309\u300c\u662f\u300d\uff09...')
        & winget install --id Rime.Weasel -e --accept-package-agreements --accept-source-agreements
        $weasel = Find-Weasel
      }
    }
    if (-not $weasel) { Fail 'Weasel could not be installed. Install weasel-0.17.4.0-installer.exe from the deps-v1 release of this project (run it as administrator), then run this script again.' (U '\u7121\u6cd5\u5b89\u88dd Weasel\u3002\u8acb\u4ee5\u7cfb\u7d71\u7ba1\u7406\u54e1\u8eab\u5206\u57f7\u884c\u672c\u5c08\u6848 deps-v1 release \u88e1\u7684 weasel-0.17.4.0-installer.exe\uff0c\u7136\u5f8c\u518d\u57f7\u884c\u672c\u8173\u672c\u3002') }
  }
}
if ($weasel) { Say "Weasel found: $weasel"; ZhL ((U '\u5df2\u627e\u5230 Weasel\uff1a') + $weasel) } else { Say 'DRY: continuing without a Weasel folder.'; ZhL (U '\u9810\u8a08\uff1a\u5728\u6c92\u6709 Weasel \u8cc7\u6599\u593e\u7684\u60c5\u6cc1\u4e0b\u7e7c\u7e8c\u3002') }
$dataDir = ''
if ($weasel) { $dataDir = Join-Path $weasel 'data' }

# ---------- 2. Rime user folder ----------
if ($RimeDir -eq '') {
  $reg = $null
  try { $reg = (Get-ItemProperty 'HKCU:\Software\Rime\Weasel' -ErrorAction Stop).RimeUserDir } catch { }
  if ($reg) { $RimeDir = $reg } else { $RimeDir = Join-Path $env:APPDATA 'Rime' }
}
Say "Rime user folder: $RimeDir"; ZhL ((U 'Rime \u4f7f\u7528\u8005\u8cc7\u6599\u593e\uff1a') + $RimeDir)
if (-not (Test-Path $RimeDir)) { if ($DryRun) { Say "DRY: would create $RimeDir"; ZhL ((U '\u9810\u8a08\u5efa\u7acb\uff1a') + $RimeDir) } else { New-Item -ItemType Directory -Path $RimeDir | Out-Null } }

# ---------- 3. schema files (local copy next to this script, else download) ----------
$here = $PSScriptRoot
$schemaFiles = @()
if ($do5) { $schemaFiles += @('cangjie5_fluency.schema.yaml', 'cangjie5_fluency.dict.yaml') }
if ($WithV2) { $schemaFiles += 'cangjie5_fluency_v2.schema.yaml' }
if ($do3) { $schemaFiles += @('cangjie3_fluency.schema.yaml', 'cangjie3_fluency.dict.yaml') }
$fz3 = $do3 -and -not $NoFuzzy
$fz5 = $do5 -and -not $NoFuzzy
if ($fz3) { $schemaFiles += @('cangjie3_fuzzy.schema.yaml', 'cangjie3_fuzzy_prism.schema.yaml') }
if ($fz5) { $schemaFiles += @('cangjie5_fuzzy.schema.yaml', 'cangjie5_fuzzy_prism.schema.yaml') }
foreach ($f in $schemaFiles) {
  $dest = Join-Path $RimeDir $f
  $local = $null
  # the typo-tolerance range (-FuzzyRange narrow|wide) is a different generated copy of the same two files
  $rel = $f
  if ($f -match '_fuzzy' -and $FuzzyRange -ne 'normal') { $rel = "fuzzy-$FuzzyRange/$f" }
  if ($here) {
    foreach ($c in @((Join-Path $here $f), (Join-Path (Join-Path $here 'weasel') $rel))) { if (Test-Path $c) { $local = $c; break } }
  }
  if ($local) {
    if ($DryRun) { Say "DRY: would copy $local -> $dest"; ZhL ((U '\u9810\u8a08\u8907\u88fd\uff1a') + "$local -> $dest") }
    else { $tmp = "$dest.part"; Copy-Item $local $tmp -Force; Place-File $tmp $dest }
  } else {
    if ($Offline) { Fail "$f is not next to this script and -Offline was given" ($f + (U ' \u4e0d\u5728\u6b64\u8173\u672c\u65c1\u908a\uff0c\u800c\u4e14\u5df2\u6307\u5b9a -Offline')) }
    Get-Remote "$SchemaRaw/$rel" $dest 500 0
  }
}

# ---------- 4. code table, word list, language model (all from this repository) ----------
if ($do5) {
  $base = Join-Path $RimeDir 'cangjie5.base.dict.yaml'
  $haveBase = (Test-Path $base) -or ($dataDir -and (Test-Path (Join-Path $dataDir 'cangjie5.base.dict.yaml')))
  if ($haveBase) { Say 'cangjie5.base.dict.yaml already present.'; ZhL (U 'cangjie5.base.dict.yaml \u5df2\u5b58\u5728\u3002') }
  elseif ($DryRun) { Say "DRY: would install tables\cangjie5.base.dict.yaml from this project"; ZhL (U '\u9810\u8a08\u5f9e\u672c\u5c08\u6848\u5b89\u88dd tables\\cangjie5.base.dict.yaml') }
  else { $t5 = Get-Staged 'tables\cangjie5.base.dict.yaml' $BaseDictUrl $BaseDictSha 100000; Place-File $t5 $base }
}

# essay.txt: the project's pinned copy is always used for the table weights (same table on every platform);
# it is installed into the user folder only when Weasel has none.
$essay = Join-Path $RimeDir 'essay.txt'
$essayPinned = $null
if (-not $DryRun) { $essayPinned = Get-Staged 'data\essay.txt' $EssayUrl $EssaySha 1000000 }
$haveEssay = (Test-Path $essay) -or ($dataDir -and (Test-Path (Join-Path $dataDir 'essay.txt')))
if ($haveEssay) { Say 'essay.txt already present in Weasel or the user folder.'; ZhL (U 'Weasel \u6216\u4f7f\u7528\u8005\u8cc7\u6599\u593e\u88e1\u5df2\u6709 essay.txt\u3002') }
elseif ($DryRun) { Say 'DRY: would install data\essay.txt from this project'; ZhL (U '\u9810\u8a08\u5f9e\u672c\u5c08\u6848\u5b89\u88dd data\\essay.txt') }
else { Copy-Item $essayPinned "$essay.part" -Force; Place-File "$essay.part" $essay }

if ($dataDir -and -not (Test-Path (Join-Path $dataDir 'luna_quanpin.schema.yaml')) -and -not (Test-Path (Join-Path $RimeDir 'luna_quanpin.schema.yaml'))) {
  Warn 'luna_quanpin.schema.yaml not found in Weasel data; pinyin reverse lookup may fail to compile. Update Weasel.'
  ZhW (U 'Weasel \u7684 data \u88e1\u627e\u4e0d\u5230 luna_quanpin.schema.yaml\uff1b\u62fc\u97f3\u53cd\u67e5\u53ef\u80fd\u7121\u6cd5\u7de8\u8b6f\u3002\u8acb\u66f4\u65b0 Weasel\u3002')
}

if ($do3) {
  $base3 = Join-Path $RimeDir 'cangjie3.base.dict.yaml'
  if ($DryRun) { Say "DRY: would convert tables\mscj3.cin from this project and install cangjie3.base.dict.yaml"; ZhL (U '\u9810\u8a08\u8f49\u63db\u672c\u5c08\u6848\u7684 tables\\mscj3.cin \u4e26\u5b89\u88dd cangjie3.base.dict.yaml') }
  else {
    $cinTmp = Get-Staged 'tables\mscj3.cin' $Cin3Url $Cin3Sha256 100000
    $tmp3 = "$base3.part"
    Convert-CinToRime $cinTmp $tmp3 $essayPinned
    Remove-Item $cinTmp -Force
    Place-File $tmp3 $base3
  }
}
if ($essayPinned) { Remove-Item $essayPinned -Force -ErrorAction SilentlyContinue }

$gram = Join-Path $RimeDir 'zh-hant-t-essay-bgw.gram'
if ($NoModel) { Say 'skipping language model (-NoModel).'; ZhL (U '\u7565\u904e\u8a9e\u8a00\u6a21\u578b\uff08-NoModel\uff09\u3002') }
elseif ((Test-Path $gram) -and ((Get-Item $gram).Length -eq $GramSize) -and ((((Get-Sha256 $gram) -replace '-', '').ToLower()) -eq $GramSha)) { Say 'language model already present.'; ZhL (U '\u8a9e\u8a00\u6a21\u578b\u5df2\u5b58\u5728\u3002') }
elseif ($DryRun) { Say 'DRY: would install data\zh-hant-t-essay-bgw.gram from this project'; ZhL (U '\u9810\u8a08\u5f9e\u672c\u5c08\u6848\u5b89\u88dd data\\zh-hant-t-essay-bgw.gram') }
else { $tg = Get-Staged 'data\zh-hant-t-essay-bgw.gram' $GramUrl $GramSha $GramSize; Place-File $tg $gram }

# ---------- 5. default.custom.yaml ----------
$dc = Join-Path $RimeDir 'default.custom.yaml'
$ids = @()
if ($FuzzyDefault) { if ($fz3) { $ids += 'cangjie3_fuzzy' }; if ($fz5) { $ids += 'cangjie5_fuzzy' } }
if ($do3) { $ids += 'cangjie3_fluency' }
if ($fz3 -and -not $FuzzyDefault) { $ids += 'cangjie3_fuzzy' }
if ($do5) { $ids += 'cangjie5_fluency' }
if ($fz5 -and -not $FuzzyDefault) { $ids += 'cangjie5_fuzzy' }
if ($WithV2) { $ids += 'cangjie5_fluency_v2' }
# ids that must sit right after their base schema (so they never become the default) when they are added to an existing list
$afterMap = @{ 'cangjie5_fluency_v2' = 'cangjie5_fluency' }
if (-not $FuzzyDefault) { $afterMap['cangjie3_fuzzy'] = 'cangjie3_fluency'; $afterMap['cangjie5_fuzzy'] = 'cangjie5_fluency' }

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
  if ($DryRun) { Say "DRY: would create $dc"; ZhL ((U '\u9810\u8a08\u5efa\u7acb\uff1a') + $dc) } else { Write-Utf8NoBom $dc $freshCrlf; Say 'created default.custom.yaml'; ZhL (U '\u5df2\u5efa\u7acb default.custom.yaml') }
} else {
  $txt = [IO.File]::ReadAllText($dc)
  # exact id match, so cangjie5_fluency is not confused with cangjie5_fluency_v2
  $missing = @($ids | Where-Object { $txt -notmatch ([regex]::Escape($_) + '(?![A-Za-z0-9_])') })
  if ($missing.Count -eq 0) {
    Say 'default.custom.yaml already lists everything needed.'
    ZhL (U 'default.custom.yaml \u5df2\u5217\u51fa\u6240\u6709\u9700\u8981\u7684\u65b9\u6848\u3002')
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
        if ($i -eq $idx) { foreach ($id in $missing) { if (-not $afterMap.ContainsKey($id)) { $new += ($indent + '- schema: ' + $id) } } }
      }
      foreach ($sp in @($missing | Where-Object { $afterMap.ContainsKey($_) })) {
        # goes right after its base schema when that is listed, so it never becomes the default
        $base = $afterMap[$sp]
        $at = -1
        for ($k = 0; $k -lt $new.Count; $k++) { if ($new[$k] -match ('schema:\s*' + [regex]::Escape($base) + '(?![A-Za-z0-9_])')) { $at = $k; break } }
        if ($at -lt 0) { $at = $idx }
        $head = @($new[0..$at]); $tail = @()
        if ($at + 1 -lt $new.Count) { $tail = @($new[($at + 1)..($new.Count - 1)]) }
        $new = $head + @($indent + '- schema: ' + $sp) + $tail
      }
      Backup-IfExists $dc
      if ($DryRun) { Say "DRY: would add $($missing -join ', ') to schema_list in $dc"; ZhL ((U '\u9810\u8a08\u5728 ') + $dc + (U ' \u7684 schema_list \u52a0\u5165\uff1a') + ($missing -join ', ')) }
      else { Write-Utf8NoBom $dc (($new -join "`r`n")); Say "added $($missing -join ', ') to the schema_list in your default.custom.yaml"; ZhL ((U '\u5df2\u5728\u4f60\u7684 default.custom.yaml \u7684 schema_list \u52a0\u5165\uff1a') + ($missing -join ', ')) }
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
        if ($DryRun) { Say "DRY: would add a schema_list ($($listBody -join ', ')) to $dc"; ZhL ((U '\u9810\u8a08\u5728 ') + $dc + (U ' \u52a0\u5165 schema_list\uff1a') + ($listBody -join ', ')) }
        else { Write-Utf8NoBom $dc (($new -join "`r`n") + "`r`n"); Say "added a schema_list to your default.custom.yaml: $($listBody -join ', ')"; ZhL ((U '\u5df2\u5728\u4f60\u7684 default.custom.yaml \u52a0\u5165 schema_list\uff1a') + ($listBody -join ', ')) }
      } else {
        Warn "Your default.custom.yaml has a non-standard 'patch:' (inline mapping), so I did not edit it. Add this under 'patch:' yourself:"
        ZhW (U '\u4f60\u7684 default.custom.yaml \u7684 patch: \u662f\u975e\u6a19\u6e96\u5beb\u6cd5\uff08\u884c\u5167\u5c0d\u61c9\uff09\uff0c\u6240\u4ee5\u6c92\u6709\u4fee\u6539\u5b83\u3002\u8acb\u81ea\u884c\u628a\u4e0b\u9762\u9019\u6bb5\u52a0\u5230 patch: \u5e95\u4e0b\uff1a')
        Write-Host "  schema_list:"
        foreach ($id in $listBody) { Write-Host "    - schema: $id" }
      }
    }
  }
}

# ---------- 6. deploy ----------
if ($NoDeploy -or $DryRun -or -not $weasel) {
  Say 'skipping deploy. Run later: Start menu > Weasel > Redeploy'
  ZhL (U '\u7565\u904e\u90e8\u7f72\u3002\u4e4b\u5f8c\u8acb\u57f7\u884c\uff1a\u958b\u59cb\u529f\u80fd\u8868 > Weasel > \u91cd\u65b0\u90e8\u7f72')
} else {
  Say 'deploying (takes about 30 seconds on first run)...'
  ZhL (U '\u90e8\u7f72\u4e2d\uff08\u7b2c\u4e00\u6b21\u7d04\u9700 30 \u79d2\uff09...')
  # Process.Start with a plain argument string: Windows PowerShell 5.1's Start-Process -ArgumentList '/deploy' sent "/deploy "
  # (trailing space), which WeaselDeployer does not recognise, so it opened the schema/theme wizard and waited for the user.
  $p = [Diagnostics.Process]::Start((Join-Path $weasel 'WeaselDeployer.exe'), '/deploy')
  $p.WaitForExit()
  if ($p.ExitCode -ne 0) { Warn "WeaselDeployer exit code $($p.ExitCode). Look at %TEMP%\rime.weasel\ for ERROR logs."; ZhW ((U 'WeaselDeployer \u7d50\u675f\u4ee3\u78bc\u70ba ') + $p.ExitCode + (U '\u3002\u8acb\u67e5\u770b %TEMP%\\rime.weasel\\ \u88e1\u7684 ERROR \u8a18\u9304\u3002')) } else { Say 'deploy finished.'; ZhL (U '\u90e8\u7f72\u5b8c\u6210\u3002') }
}

# ---------- 6.5. Sweep Pad ----------
$sweepInstalled = $false
$sweepSelfCheckOk = $false
$sweepSelfCheckMsg = ''
$sweepPythonFound = $false

if ($NoSweep) {
  Say 'skipping Sweep Pad (-NoSweep).'
  ZhL (U '\u7565\u904e\u5009\u9821\u6ed1\u884c\u9762\u677f\uff08-NoSweep\uff09\u3002')
} else {
  $pyExe = $null
  $pyArgs = @()
  $pywExe = $null

  $pyCands = @(
    @{ Cmd = 'py'; Args = @('-3') },
    @{ Cmd = 'python'; Args = @() }
  )
  foreach ($cand in $pyCands) {
    $cmd = Get-Command $cand.Cmd -ErrorAction SilentlyContinue
    if (-not $cmd) { continue }
    try {
      $psi = New-Object Diagnostics.ProcessStartInfo
      $psi.FileName = $cmd.Source
      $tArgs = $cand.Args + @('-c', 'import sys, tkinter; sys.exit(0 if sys.version_info >= (3, 8) else 1)')
      $psi.Arguments = ($tArgs | ForEach-Object { if ($_ -match ' ') { '"' + $_ + '"' } else { $_ } }) -join ' '
      $psi.UseShellExecute = $false
      $psi.CreateNoWindow = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      $p = [Diagnostics.Process]::Start($psi)
      $p.WaitForExit(5000)
      if ($p.ExitCode -eq 0) {
        $pyExe = $cmd.Source
        $pyArgs = $cand.Args
        $sweepPythonFound = $true
        break
      }
    } catch { }
  }

  if (-not $sweepPythonFound) {
    Warn 'Python 3.8+ with tkinter was not found. Sweep Pad requires Python with tkinter.'
    ZhW (U '\u627e\u4e0d\u5230\u652f\u63f4 tkinter \u7684 Python 3.8+ \u7248\u672c\u3002\u5009\u9821\u6ed1\u884c\u9762\u677f\u9700\u8981 Python \u8207 tkinter\u3002')
    Say 'To install Python, run: winget install Python.Python.3.12'
    ZhL (U '\u5b89\u88dd Python \u8acb\u57f7\u884c\uff1awinget install Python.Python.3.12')
  } else {
    $pywCmd = Get-Command 'pythonw' -ErrorAction SilentlyContinue
    if ($pywCmd) { $pywExe = $pywCmd.Source }
    elseif ($pyExe) {
      $candW = Join-Path (Split-Path $pyExe) 'pythonw.exe'
      if (Test-Path $candW) { $pywExe = $candW }
    }
    if (-not $pywExe) { $pywExe = 'pythonw.exe' }
  }

  if ($DryRun) {
    Say "DRY: would install Sweep Pad ($PadRef) to $sweepDir"
    ZhL ((U '\u9810\u8a08\u5b89\u88dd\u5009\u9821\u6ed1\u884c\u9762\u677f\uff08') + $PadRef + (U '\uff09\u81f3 ') + $sweepDir)
    Say "DRY: would create Start Menu shortcut 'Cangjie Sweep' and cangjie-sweep.bat"
    ZhL (U '\u9810\u8a08\u5efa\u7acb\u958b\u59cb\u529f\u80fd\u8868\u6377\u5f91\u300cCangjie Sweep \u5009\u9821\u6ed1\u884c\u300d\u8207 cangjie-sweep.bat')
  } else {
    $localZip = $null
    $localSha = $null
    if ($here) {
      $zipCands = @(
        (Join-Path $here (Join-Path 'sweep-pad' 'cangjie-sweep-pad.zip')),
        (Join-Path $here (Join-Path 'sweep-pad' $PadZipName)),
        (Join-Path $here 'cangjie-sweep-pad.zip'),
        (Join-Path $here $PadZipName)
      )
      foreach ($zc in $zipCands) { if (Test-Path $zc) { $localZip = $zc; break } }

      $shaCands = @(
        (Join-Path $here (Join-Path 'sweep-pad' 'cangjie-sweep-pad.zip.sha256')),
        (Join-Path $here (Join-Path 'sweep-pad' "$PadZipName.sha256")),
        (Join-Path $here 'cangjie-sweep-pad.zip.sha256'),
        (Join-Path $here "$PadZipName.sha256")
      )
      foreach ($sc in $shaCands) { if (Test-Path $sc) { $localSha = $sc; break } }
    }

    $stagedZip = $null
    $stagedSha = $null
    $isTempZip = $false
    $isTempSha = $false

    if ($localZip) {
      $stagedZip = $localZip
      Say "using local Sweep Pad zip: $localZip"
      ZhL ((U '\u4f7f\u7528\u672c\u6a5f\u6ed1\u884c\u9762\u677f\u58d3\u7e2e\u5305\uff1a') + $localZip)
    } elseif ($Offline) {
      Warn "cangjie-sweep-pad.zip was not found next to this script and -Offline was given; skipping Sweep Pad."
      ZhW (U '\u5728\u672c\u6a5f\u627e\u4e0d\u5230 cangjie-sweep-pad.zip \u4e14\u5df2\u6307\u5b9a -Offline\uff1b\u7565\u904e\u5009\u9821\u6ed1\u884c\u9762\u677f\u3002')
    } else {
      $tmpZ = Join-Path ([IO.Path]::GetTempPath()) ("cjf-sweep-$Stamp-$PadZipName")
      Say "downloading $PadUrl"
      ZhL ((U '\u4e0b\u8f09\u4e2d\uff1a') + $PadUrl)
      try {
        Invoke-WebRequest -Uri $PadUrl -OutFile $tmpZ -UseBasicParsing
        $stagedZip = $tmpZ
        $isTempZip = $true
      } catch {
        Warn "could not download Sweep Pad zip: $($_.Exception.Message)"
        ZhW ((U '\u7121\u6cd5\u4e0b\u8f09\u5009\u9821\u6ed1\u884c\u9762\u677f\u58d3\u7e2e\u5305\uff1a') + $_.Exception.Message)
      }
    }

    if ($stagedZip) {
      if ($localSha) {
        $stagedSha = $localSha
      } elseif ($Offline) {
        # offline with no sha file
      } else {
        $tmpS = Join-Path ([IO.Path]::GetTempPath()) ("cjf-sweep-$Stamp-$PadZipName.sha256")
        try {
          Invoke-WebRequest -Uri $PadShaUrl -OutFile $tmpS -UseBasicParsing
          $stagedSha = $tmpS
          $isTempSha = $true
        } catch {
          Warn "could not download Sweep Pad checksum: $($_.Exception.Message)"
          ZhW ((U '\u7121\u6cd5\u4e0b\u8f09\u5009\u9821\u6ed1\u884c\u9762\u677f\u6821\u9a57\u78bc\uff1a') + $_.Exception.Message)
        }
      }

      if ($stagedSha -and (Test-Path $stagedSha)) {
        $shaContent = [IO.File]::ReadAllText($stagedSha).Trim()
        $m = [regex]::Match($shaContent, '([0-9a-fA-F]{64})')
        if ($m.Success) {
          $expectedHash = $m.Groups[1].Value.ToLower()
          $actualHash = ((Get-Sha256 $stagedZip) -replace '-', '').ToLower()
          if ($actualHash -ne $expectedHash) {
            if ($isTempZip) { Remove-Item $stagedZip -Force -ErrorAction SilentlyContinue }
            if ($isTempSha) { Remove-Item $stagedSha -Force -ErrorAction SilentlyContinue }
            Fail "Sweep Pad zip SHA-256 mismatch: got $actualHash, expected $expectedHash" ((U '\u5009\u9821\u6ed1\u884c\u9762\u677f\u58d3\u7e2e\u5305 SHA-256 \u4e0d\u7b26\uff1a\u5be6\u969b\u70ba ') + $actualHash + (U '\uff0c\u9810\u671f\u70ba ') + $expectedHash)
          }
          Say 'Sweep Pad zip checksum verified.'
          ZhL (U '\u5009\u9821\u6ed1\u884c\u9762\u677f\u58d3\u7e2e\u5305\u6821\u9a57\u78bc\u6b63\u78ba\u3002')
        }
      }

      $tmpExtract = Join-Path ([IO.Path]::GetTempPath()) ("cjf-sweepext-$Stamp")
      if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue }
      New-Item -ItemType Directory -Path $tmpExtract | Out-Null
      try {
        try { Add-Type -AssemblyName System.IO.Compression.FileSystem } catch { }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($stagedZip, $tmpExtract)

        if (-not (Test-Path $sweepDir)) {
          New-Item -ItemType Directory -Path $sweepDir -Force | Out-Null
        }

        Get-ChildItem -Path $tmpExtract | ForEach-Object {
          Copy-Item -Path $_.FullName -Destination $sweepDir -Recurse -Force
        }
        $sweepInstalled = $true
        Say "Sweep Pad installed to $sweepDir"
        ZhL ((U '\u5009\u9821\u6ed1\u884c\u9762\u677f\u5df2\u5b89\u88dd\u81f3\uff1a') + $sweepDir)
      } catch {
        Warn "Failed to extract Sweep Pad: $($_.Exception.Message)"
        ZhW ((U '\u89e3\u58d3\u7e2e\u5009\u9821\u6ed1\u884c\u9762\u677f\u5931\u6548\uff1a') + $_.Exception.Message)
      } finally {
        if (Test-Path $tmpExtract) { Remove-Item $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue }
        if ($isTempZip) { Remove-Item $stagedZip -Force -ErrorAction SilentlyContinue }
        if ($isTempSha) { Remove-Item $stagedSha -Force -ErrorAction SilentlyContinue }
      }
    }

    if ($sweepInstalled) {
      $sweepPyScript = Join-Path $sweepDir 'cangjie_sweep_pad.py'

      $batLines = @(
        '@echo off',
        'setlocal',
        'cd /d "%~dp0"',
        'where pythonw >nul 2>&1',
        'if %ERRORLEVEL% EQU 0 (',
        '  start "" pythonw "%~dp0cangjie_sweep_pad.py" %*',
        '  exit /b 0',
        ')',
        'where py >nul 2>&1',
        'if %ERRORLEVEL% EQU 0 (',
        '  start "" py -3 "%~dp0cangjie_sweep_pad.py" %*',
        '  exit /b 0',
        ')',
        'where python >nul 2>&1',
        'if %ERRORLEVEL% EQU 0 (',
        '  start "" python "%~dp0cangjie_sweep_pad.py" %*',
        '  exit /b 0',
        ')',
        'echo Python 3.8+ with tkinter was not found.',
        'echo Install it with: winget install Python.Python.3.12',
        'pause'
      )
      $batPath = Join-Path $sweepDir 'cangjie-sweep.bat'
      [IO.File]::WriteAllText($batPath, ($batLines -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
      Say "Created launcher: $batPath"
      ZhL ((U '\u5df2\u5efa\u7acb\u555f\u52d5\u6a94\uff1a') + $batPath)

      try {
        $programsDir = [Environment]::GetFolderPath('Programs')
        if (-not $programsDir -and $env:APPDATA) {
          $programsDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
        }
        if ($programsDir -and (Test-Path $programsDir)) {
          $scName = (U 'Cangjie Sweep \u5009\u9821\u6ed1\u884c.lnk')
          $scPath = Join-Path $programsDir $scName
          $wsh = New-Object -ComObject WScript.Shell
          $sc = $wsh.CreateShortcut($scPath)
          $sc.TargetPath = if ($pywExe) { $pywExe } else { 'pythonw.exe' }
          $sc.Arguments = "`"$sweepPyScript`""
          $sc.WorkingDirectory = $sweepDir
          $sc.Description = 'Cangjie Sweep Pad'
          $sc.Save()
          Say "Created Start Menu shortcut: $scName"
          ZhL ((U '\u5df2\u5efa\u7acb\u958b\u59cb\u529f\u80fd\u8868\u6377\u5f91\uff1a') + $scName)
        }
      } catch { }

      if ($sweepPythonFound -and (Test-Path $sweepPyScript)) {
        try {
          $psi = New-Object Diagnostics.ProcessStartInfo
          $psi.FileName = $pyExe
          $scArgs = $pyArgs + @($sweepPyScript, '--self-check')
          $psi.Arguments = ($scArgs | ForEach-Object { if ($_ -match ' ') { '"' + $_ + '"' } else { $_ } }) -join ' '
          $psi.UseShellExecute = $false
          $psi.CreateNoWindow = $true
          $psi.RedirectStandardOutput = $true
          $psi.RedirectStandardError = $true
          $psi.WorkingDirectory = $sweepDir
          $p = [Diagnostics.Process]::Start($psi)
          $outStr = $p.StandardOutput.ReadToEnd()
          $errStr = $p.StandardError.ReadToEnd()
          $p.WaitForExit(10000)
          if ($p.ExitCode -eq 0) {
            $sweepSelfCheckOk = $true
            Say 'Sweep Pad self-check passed.'
            ZhL (U '\u5009\u9821\u6ed1\u884c\u9762\u677f\u81ea\u6aa2\u6210\u529f\u3002')
          } else {
            $sweepSelfCheckMsg = ($outStr + ' ' + $errStr).Trim()
            Warn "Sweep Pad self-check returned exit code $($p.ExitCode): $sweepSelfCheckMsg"
            ZhW ((U '\u5009\u9821\u6ed1\u884c\u9762\u677f\u81ea\u6aa2\u50b3\u56de\u932f\u8aa4\u78bc ') + $p.ExitCode + ': ' + $sweepSelfCheckMsg)
          }
        } catch {
          Warn "Could not run Sweep Pad self-check: $($_.Exception.Message)"
          ZhW ((U '\u7121\u6cd5\u57f7\u884c\u5009\u9821\u6ed1\u884c\u9762\u677f\u81ea\u6aa2\uff1a') + $_.Exception.Message)
        }
      }
    }
  }
}

# ---------- 7. what next ----------
Write-Host ''
Say 'Done. Next steps:'
Zh '\u5b8c\u6210\u3002\u63a5\u4e0b\u4f86\uff1a'
if ($do3) {
  if ($FuzzyDefault -and $fz3) {
    Write-Host '  1. The default schema is "cangjie3_fuzzy" (3rd-generation sentence-style Cangjie with adjacent-key typo tolerance): no Ctrl+` or F4 needed. Plain "cangjie3_fluency" is listed right after it.'
    Write-Host ('    ' + [regex]::Unescape('1. \u9810\u8a2d\u65b9\u6848\u5c31\u662f\u300ccangjie3_fuzzy\u300d\uff08\u5009\u9821\u4e09\u4ee3\u6574\u53e5\uff0c\u9644\u9130\u9375\u5bb9\u932f\uff09\uff0c\u4e0d\u5fc5\u6309 Ctrl+` \u6216 F4\uff1b\u4e00\u822c\u7684\u300ccangjie3_fluency\u300d\u6392\u5728\u5b83\u5f8c\u9762\u3002'))
  } else {
    Write-Host '  1. Press Ctrl+` (or F4) in any text box and choose the schema "cangjie3_fluency" (3rd-generation sentence-style Cangjie, listed first).'
    Write-Host ('    ' + [regex]::Unescape('\u5728\u4efb\u4f55\u8f38\u5165\u6846\u6309 Ctrl+`\uff08\u6216 F4\uff09\uff0c\u9078\u300ccangjie3_fluency\u300d\uff08\u5009\u9821\u4e09\u4ee3\u6574\u53e5\u7248\uff0c\u6392\u5728\u6700\u524d\u9762\uff09\u3002'))
  }
  Write-Host '  2. Type dhedhkb  (should become the two characters for Banqiao as you type the last code); mwyl gives the character for "face".'
  Write-Host ('    ' + [regex]::Unescape('\u8f38\u5165 dhedhkb \u6703\u8b8a\u6210\u300c\u677f\u6a4b\u300d\uff1b\u8f38\u5165 mwyl \u6703\u51fa\u73fe\u300c\u9762\u300d\u3002'))
  if ($fz3) {
    if ($FuzzyDefault) {
      Write-Host '  Adjacent-key typo tolerance is the DEFAULT schema (cangjie3_fuzzy): yhmbv also offers the character typed as yhmbc. The exact candidates stay first. Plain cangjie3_fluency is listed right after it.'
      Write-Host ('    ' + [regex]::Unescape('\u9130\u9375\u5bb9\u932f\uff08cangjie3_fuzzy\uff09\u662f\u9810\u8a2d\u65b9\u6848\uff0c\u4e0d\u5fc5\u6309 Ctrl+` \u6216 F4\uff1a\u6253\u932f\u4e00\u500b\u76f8\u9130\u6309\u9375\uff08\u4f8b\u5982 yhmbv\uff09\u4e5f\u6703\u51fa yhmbc \u7684\u300c\u984f\u300d\uff0c\u6b63\u78ba\u7684\u5019\u9078\u4ecd\u6392\u5728\u6700\u524d\u9762\u3002\u4e00\u822c\u7684 cangjie3_fluency \u5c31\u6392\u5728\u5b83\u5f8c\u9762\u3002'))
    } else {
      Write-Host '  Optional: choose "cangjie3_fuzzy" (second in the list) to also get candidates when ONE key is off by an adjacent key (yhmbv also offers the character typed as yhmbc).'
      Write-Host ('    ' + [regex]::Unescape('\u9078\u7528\uff1a\u6539\u9078\u6e05\u55ae\u4e2d\u7b2c\u4e8c\u500b\u300ccangjie3_fuzzy\u300d\uff0c\u6253\u932f\u4e00\u500b\u76f8\u9130\u6309\u9375\uff08\u4f8b\u5982 yhmbv\uff09\u4e5f\u6703\u51fa yhmbc \u7684\u300c\u984f\u300d\uff0c\u6b63\u78ba\u7684\u5019\u9078\u4ecd\u6392\u5728\u6700\u524d\u9762\u3002'))
    }
  }
} else {
  Write-Host '  1. Press Ctrl+` (or F4) in any text box and choose the schema "cangjie5_fluency" (5th-generation sentence-style Cangjie).'
  Write-Host ('    ' + [regex]::Unescape('\u5728\u4efb\u4f55\u8f38\u5165\u6846\u6309 Ctrl+`\uff08\u6216 F4\uff09\uff0c\u9078\u300ccangjie5_fluency\u300d\uff08\u5009\u9821\u4e94\u4ee3\u6574\u53e5\u7248\uff09\u3002'))
  Write-Host '  2. Type dhedhkb  (should become the two characters for Banqiao as you type the last code).'
  Write-Host ('    ' + [regex]::Unescape('\u8f38\u5165 dhedhkb \u6703\u8b8a\u6210\u300c\u677f\u6a4b\u300d\u3002'))
}
Write-Host '  3. Check the language model loaded (after you typed once with the schema):'
Write-Host ('  ' + [regex]::Unescape('3. \u78ba\u8a8d\u8a9e\u8a00\u6a21\u578b\u5df2\u8f09\u5165\uff1a\u6253\u4e00\u6b21\u5b57\u4e4b\u5f8c\u57f7\u884c\u4e0b\u9762\u9019\u884c\uff0c\u770b\u5230 use grammar \u4e14\u5f8c\u9762\u6c92\u6709 failed to load grammar database \u5c31\u662f\u6210\u529f\u3002'))
Write-Host '       Select-String -Path "$env:TEMP\rime.weasel\*.log" -Pattern "use grammar|failed to load grammar" | Select -Last 5'
Write-Host '     Loaded = a "use grammar" line and NO "failed to load grammar database" line after it.'
Write-Host '     (The "use grammar" line is also printed when the .gram file is missing; the failure line is what tells them apart.)'
if (-not $NoSweep) {
  Write-Host '  4. Cangjie Sweep Pad (mouse/touch glide typing):'
  Write-Host ('    ' + [regex]::Unescape('4. \u5009\u9821\u6ed1\u884c\u9762\u677f\uff08\u6ed1\u9f20\uff0f\u89f8\u63a7\u6ed1\u884c\u8f38\u5165\uff09\uff1a'))
  Write-Host ('     - Open from Start Menu: "' + (U 'Cangjie Sweep \u5009\u9821\u6ed1\u884c') + '" (or run ' + (Join-Path $sweepDir 'cangjie-sweep.bat') + ')')
  Write-Host ('       ' + [regex]::Unescape('\u5f9e\u958b\u59cb\u529f\u80fd\u8868\u958b\u555f\u300cCangjie Sweep \u5009\u9821\u6ed1\u884c\u300d\uff08\u6216\u57f7\u884c ') + (Join-Path $sweepDir 'cangjie-sweep.bat') + [regex]::Unescape('\uff09\u3002'))
  Write-Host '     - IMPORTANT: Weasel (Rime) MUST be the active input method in your target application.'
  Write-Host ('       ' + [regex]::Unescape('\u91cd\u8981\uff1a\u76ee\u6a19\u61c9\u7528\u7a0b\u5f0f\u5167\u5fc5\u9808\u4ee5\u5c0f\u72fc\u6beb\uff08Rime\uff09\u70ba\u7576\u524d\u4f5c\u7528\u8f38\u5165\u6cd5\u3002'))
  if ($sweepSelfCheckOk) {
    Write-Host '     - Self-check: PASSED.'
    Write-Host ('       ' + [regex]::Unescape('\u81ea\u6aa2\uff1a\u901a\u904e\u3002'))
  } elseif (-not $sweepPythonFound) {
    Write-Host '     - Python 3.8+ with tkinter is needed to run the Sweep Pad. Install via:'
    Write-Host '         winget install Python.Python.3.12'
    Write-Host ('       ' + [regex]::Unescape('\u57f7\u884c\u6ed1\u884c\u9762\u677f\u9700\u8981 Python 3.8+ \u53ca tkinter\uff0c\u5b89\u88dd\u6307\u4ee4\uff1a'))
    Write-Host '         winget install Python.Python.3.12'
  }
}
} } catch {
  Write-Host "[cangjie-fluency] ERROR: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host ('                  ' + [regex]::Unescape('\u932f\u8aa4\uff1a') + $(if ($_.Exception.Data['zh']) { $_.Exception.Data['zh'] } else { $_.Exception.Message })) -ForegroundColor Red
  Write-Host '[cangjie-fluency] Stopped. Files written before this point are kept (existing ones were backed up as *.bak-<time>).' -ForegroundColor Red
  Write-Host ('                  ' + [regex]::Unescape('\u5df2\u505c\u6b62\u3002\u5728\u6b64\u4e4b\u524d\u5beb\u5165\u7684\u6a94\u6848\u90fd\u6703\u4fdd\u7559\uff08\u539f\u6709\u6a94\u6848\u5df2\u5099\u4efd\u70ba *.bak-<\u6642\u9593>\uff09\u3002')) -ForegroundColor Red
}
