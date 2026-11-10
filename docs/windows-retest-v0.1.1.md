# Windows re-test of cangjie-fluency v0.1.1 (for the Windows-side Claude)

Goal: confirm the fixes made after your v0.1.0 test. Report results as a table at the end. Work carefully: this is the
owner's real machine.

## Safety rules (read first)

1. **Back up first**: copy `%APPDATA%\Rime` (the whole folder) to `%TEMP%\rime-backup-<timestamp>` before any test, and say where it is.
2. **Do NOT use plum / rime-install** at all (it already broke the real `default.custom.yaml` once; known and documented).
3. Do not uninstall Weasel and do not log the owner out without asking.
4. All commits (if any) must use `huangjs@gmail.com`, no Co-Authored-By.
5. Do not paste secrets into any reply.

## Get the code under test

Test exactly the published script, not a local edit:

```powershell
$u = 'https://raw.githubusercontent.com/githubhjs/cangjie-fluency/v0.1.1/install.ps1'
```

(The tag `v0.1.1` is at commit `e861a6c`. The default `main` may be newer; for this test use the tag.)

## Tests

### T1. Normal run through `irm | iex`, PowerShell 5.1 and 7
Run `irm $u | iex` once in `powershell.exe` (5.1) and once in `pwsh` (7). Expected: finishes, deploy exit code 0, no garbled text,
`cangjie5_fluency.schema.yaml` / `.dict.yaml` in `%APPDATA%\Rime` identical to the repo files. Report the printed lines.

### T2. Session is not damaged (the v0.1.0 bugs)
In the same PowerShell window right after T1, run:
`$ErrorActionPreference; $Stamp; $DryRun; $NeedRelogin`
Expected: `Continue` and three empty values (v0.1.0 left `Stop` and a timestamp).

### T3. Error path must not close the window
Force an error without breaking anything: save the script locally and run it with a Weasel folder that does not exist:
```powershell
irm $u -OutFile $env:TEMP\install-t.ps1
& $env:TEMP\install-t.ps1 -SkipWeaselInstall -WeaselDir C:\does\not\exist -RimeDir $env:TEMP\rime-t3 -DryRun
```
Expected: a red `ERROR: Weasel is not installed ...` line and a red `Stopped` line, **and the PowerShell window stays open**.
Then try the same through `iex`: `Get-Content $env:TEMP\install-t.ps1 -Raw | iex` is not parameterised, so instead run
`& ([scriptblock]::Create((Get-Content $env:TEMP\install-t.ps1 -Raw))) -SkipWeaselInstall -WeaselDir C:\does\not\exist -RimeDir $env:TEMP\rime-t3 -DryRun`
and confirm the window survives.

### T4. `default.custom.yaml` merge cases (use a scratch folder, never the real one)
Use `-RimeDir $env:TEMP\rime-t4-<n> -NoDeploy -NoModel -WeaselDir <the real Weasel dir>` and pre-create `default.custom.yaml` as:
a. missing -> expect a new file with `schema_list` (cangjie5_fluency, cangjie5, luna_pinyin) and **no LF-only lines** (all CRLF).
b. a list that contains only `- schema: cangjie5_fluency_v2` -> expect `cangjie5_fluency` **added** (not "already lists").
c. the old Weasel menu format (`- {schema: x}` items plus `customization:`) with **no trailing newline** -> expect an inserted line and a valid YAML result; show the final file.
d. a file with no `schema_list` -> expect it untouched and a printed hint.
e. a list that already has `cangjie5_fluency` -> expect "already lists", file unchanged.

### T5. Real install on the real folder (only after T1-T4 pass and the backup exists)
Already done by T1. Confirm in a text box: switch to the sentence-style Cangjie, type `dhedhkb` -> `板橋`, and run
`Select-String -Path "$env:TEMP\rime.weasel\*.log" -Pattern 'use grammar' | Select -Last 3` -> a `use grammar: zh-hant-t-essay-bgw` line.

### T6. Not testable on this machine (just say so)
Fresh machine from zero (no Weasel yet: winget install, UAC, first deploy). Do NOT uninstall Weasel to test it.

## Report format

A table `T1..T6` with PASS / FAIL / NOT RUN, the evidence line for each, then a list of any new bugs with a suggested fix.
Mention what you left behind (backup folders, `*.bak-*` files, scratch folders) so the owner can delete them.
