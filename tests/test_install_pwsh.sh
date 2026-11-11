#!/usr/bin/env bash
# throwaway checks of the Windows installer under pwsh on Linux (fake Weasel folder, -NoDeploy, -Offline, local bundle)
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T=$(mktemp -d /tmp/ps1fz.XXXXXX)
W="$T/weasel/data"; mkdir -p "$W"; : >"$T/weasel/WeaselDeployer.exe"
printf 'schema_list:\n  - schema: luna_pinyin\n  - schema: cangjie5\n' >"$W/default.yaml"
run() { local d="$1"; shift; pwsh -NoProfile -File "$REPO/install.ps1" -Offline -NoDeploy -NoModel -SkipWeaselInstall -WeaselDir "$T/weasel" -RimeDir "$d" "$@" >"$T/out" 2>&1; echo "rc=$?"; }
ids() { grep -o 'schema: [A-Za-z0-9_]*' "$1/default.custom.yaml" | cut -c9- | tr '\n' ' '; echo; }
PASS=0; FAIL=0
chk() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "ok   $1"; else FAIL=$((FAIL+1)); echo "FAIL $1"; echo "   got : $2"; echo "   want: $3"; fi; }

d="$T/a"; mkdir -p "$d"; run "$d" >/dev/null
chk "A fresh default: files" "$(ls "$d" | grep -c fuzzy)" "2"
chk "A fresh default: list" "$(ids "$d")" "cangjie3_fluency cangjie3_fuzzy luna_pinyin cangjie5 "

d="$T/b"; mkdir -p "$d"; run "$d" -FuzzyDefault -Cangjie5 >/dev/null
chk "B fuzzy default + cj5: list" "$(ids "$d")" "cangjie3_fuzzy cangjie5_fuzzy cangjie3_fluency cangjie5_fluency luna_pinyin cangjie5 "
chk "B files" "$(ls "$d" | grep -c fuzzy)" "4"

d="$T/c"; mkdir -p "$d"; printf 'patch:\n  schema_list:\n    - schema: cangjie3_fluency\n    - schema: luna_pinyin\n' >"$d/default.custom.yaml"; run "$d" >/dev/null
chk "C existing fluency first: fuzzy goes right after it" "$(ids "$d")" "cangjie3_fluency cangjie3_fuzzy luna_pinyin "

d="$T/d"; mkdir -p "$d"; printf 'patch:\n  schema_list:\n    - schema: luna_pinyin\n' >"$d/default.custom.yaml"; run "$d" -FuzzyDefault >/dev/null
chk "D existing list, FuzzyDefault: fuzzy first" "$(ids "$d")" "cangjie3_fuzzy cangjie3_fluency luna_pinyin "

d="$T/e"; mkdir -p "$d"; run "$d" >/dev/null; b=$(md5sum <"$d/default.custom.yaml"); run "$d" >/dev/null
chk "E second run leaves the list alone" "$(md5sum <"$d/default.custom.yaml")" "$b"
chk "E no backup on identical rerun" "$(ls "$d" | grep -c bak)" "0"

d="$T/f"; mkdir -p "$d"; run "$d" -NoFuzzy >/dev/null
chk "F -NoFuzzy: no fuzzy file" "$(ls "$d" | grep -c fuzzy)" "0"
chk "F -NoFuzzy: list" "$(ids "$d")" "cangjie3_fluency luna_pinyin cangjie5 "

d="$T/g"; mkdir -p "$d"; printf 'patch:\n  schema_list:\n    - schema: cangjie3_fuzzy\n    - schema: luna_pinyin\n' >"$d/default.custom.yaml"; run "$d" >/dev/null
chk "G user put fuzzy first: fluency added, user order of fuzzy kept at top" "$(ids "$d")" "cangjie3_fluency cangjie3_fuzzy luna_pinyin "
for rg in narrow wide; do
  d="$T/r_$rg"; mkdir -p "$d"; run "$d" -Cangjie5 -FuzzyRange $rg >/dev/null
  chk "range $rg: cj3 fuzzy file is the $rg copy" "$(cmp -s "$REPO/weasel/fuzzy-$rg/cangjie3_fuzzy.schema.yaml" "$d/cangjie3_fuzzy.schema.yaml" && echo same)" same
  chk "range $rg: cj5 prism file is the $rg copy" "$(cmp -s "$REPO/weasel/fuzzy-$rg/cangjie5_fuzzy_prism.schema.yaml" "$d/cangjie5_fuzzy_prism.schema.yaml" && echo same)" same
done
d="$T/r_bad"; mkdir -p "$d"; run "$d" -FuzzyRange huge | grep -q 'rc=0' && r=accepted || r=refused
chk "range huge is refused" "$r" refused

d="$T/sw_dry"; mkdir -p "$d"; run "$d" -DryRun >/dev/null
chk "Sweep dry-run without -NoSweep: announces sweep install" "$(grep -c 'would install Sweep Pad' "$T/out")" "1"

d="$T/sw_nosweep"; mkdir -p "$d"; run "$d" -DryRun -NoSweep >/dev/null
chk "Sweep dry-run with -NoSweep: skips sweep" "$(grep -c 'skipping Sweep Pad' "$T/out")" "1"

FAKEBIN="$T/nopy_bin"; mkdir -p "$FAKEBIN"
for f in /usr/bin/* /bin/*; do
  [ -e "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in
    python*|py|py3*) ;;
    *) ln -s "$f" "$FAKEBIN/$bn" 2>/dev/null || true ;;
  esac
done
ln -s "$(command -v pwsh)" "$FAKEBIN/pwsh" 2>/dev/null || true
d="$T/sw_nopy"; mkdir -p "$d"
PATH="$FAKEBIN" run "$d" >/dev/null
chk "Missing python prints winget instructions" "$(grep -q 'winget install Python.Python.3.12' "$T/out" && echo printed)" "printed"

F="$T/fake_release"; mkdir -p "$F/sweep-pad"
ln -s "$REPO/install.ps1" "$F/install.ps1"
ln -s "$REPO/weasel" "$F/weasel"
ln -s "$REPO/tables" "$F/tables"
ln -s "$REPO/data" "$F/data"
printf 'bad-zip-content\n' > "$F/sweep-pad/cangjie-sweep-pad.zip"
printf '0000000000000000000000000000000000000000000000000000000000000000  cangjie-sweep-pad.zip\n' > "$F/sweep-pad/cangjie-sweep-pad.zip.sha256"

d="$T/sw_badhash"; mkdir -p "$d"
LOCALAPPDATA="$T/bad_lap" pwsh -NoProfile -File "$F/install.ps1" -Offline -NoDeploy -NoModel -SkipWeaselInstall -WeaselDir "$T/weasel" -RimeDir "$d" >"$T/out" 2>&1 || true
chk "Hash mismatch refusal: reported error" "$(grep -q 'SHA-256 mismatch' "$T/out" && echo refused)" "refused"
chk "Hash mismatch refusal: no partial install" "$([ ! -d "$T/bad_lap/cangjie-sweep" ] && echo clean)" "clean"

G="$T/good_release"; mkdir -p "$G/sweep-pad"
ln -s "$REPO/install.ps1" "$G/install.ps1"
ln -s "$REPO/weasel" "$G/weasel"
ln -s "$REPO/tables" "$G/tables"
ln -s "$REPO/data" "$G/data"
python3 -c '
import zipfile
with zipfile.ZipFile("'"$G"'/sweep-pad/cangjie-sweep-pad.zip", "w") as z:
    z.writestr("cangjie_sweep_pad.py", "#!/usr/bin/env python3\nimport sys\nif \"--self-check\" in sys.argv:\n    sys.exit(0)\n")
'
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "$G/sweep-pad/cangjie-sweep-pad.zip" > "$G/sweep-pad/cangjie-sweep-pad.zip.sha256"
else
  shasum -a 256 "$G/sweep-pad/cangjie-sweep-pad.zip" > "$G/sweep-pad/cangjie-sweep-pad.zip.sha256"
fi

d="$T/sw_good"; mkdir -p "$d"
LOCALAPPDATA="$T/lap" pwsh -NoProfile -File "$G/install.ps1" -Offline -NoDeploy -NoModel -SkipWeaselInstall -WeaselDir "$T/weasel" -RimeDir "$d" >"$T/out" 2>&1
chk "Valid bundle: extracts cangjie_sweep_pad.py" "$([ -f "$T/lap/cangjie-sweep/cangjie_sweep_pad.py" ] && echo installed)" "installed"
chk "Valid bundle: creates cangjie-sweep.bat" "$([ -f "$T/lap/cangjie-sweep/cangjie-sweep.bat" ] && echo created)" "created"

LOCALAPPDATA="$T/lap" pwsh -NoProfile -File "$G/install.ps1" -Uninstall >"$T/out" 2>&1
chk "Uninstall: removes cangjie-sweep directory" "$([ ! -d "$T/lap/cangjie-sweep" ] && echo uninstalled)" "uninstalled"

echo "passed: $PASS failed: $FAIL"
