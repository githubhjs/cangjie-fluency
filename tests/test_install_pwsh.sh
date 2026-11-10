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
echo "passed: $PASS failed: $FAIL"
