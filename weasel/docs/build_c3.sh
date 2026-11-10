#!/usr/bin/env bash
# usage: build_c3.sh NAME   -> testenv/NAME with cangjie5_fluency + cangjie3_fluency, table generated from
# testenv/dl3/mscj3.cin (never committed). Needs rimebin/ and testenv/shared_nogy from the earlier setup.
set -eu
P="$(cd "$(dirname "$0")/../.." && pwd)"
R="$P/rimebin/root"
export LD_LIBRARY_PATH="$R/usr/lib/aarch64-linux-gnu"
U="$P/testenv/$1"
mkdir -p "$U"
cp "$P"/weasel/cangjie5_fluency.schema.yaml "$P"/weasel/cangjie5_fluency.dict.yaml \
   "$P"/weasel/cangjie3_fluency.schema.yaml "$P"/weasel/cangjie3_fluency.dict.yaml "$U"/
if [ "${PLAIN:-0}" = 1 ]; then
  python3 -I "$P/tools/cin2rime.py" "$P/testenv/dl3/mscj3.cin" "$U/cangjie3.base.dict.yaml"
else
  python3 -I "$P/tools/cin2rime.py" "$P/testenv/dl3/mscj3.cin" "$U/cangjie3.base.dict.yaml" --essay "$P/testenv/shared/essay.txt"
fi
printf 'patch:\n  schema_list:\n    - schema: cangjie3_fluency\n    - schema: cangjie5_fluency\n' > "$U/default.custom.yaml"
time "$R/usr/bin/rime_deployer" --build "$U" "${SHARED:-$P/testenv/shared_nogy}"
echo "build exit=$?"
ls -l "$U/build"
