#!/usr/bin/env bash
# usage: build_test.sh USERDIR_NAME   -> creates testenv/NAME with the current schema, deploys it
set -eu
P="$(cd "$(dirname "$0")/../.." && pwd)"
R="$P/rimebin/root"
export LD_LIBRARY_PATH="$R/usr/lib/aarch64-linux-gnu"
U="$P/testenv/$1"
mkdir -p "$U"
cp "$P"/weasel/cangjie5_fluency.schema.yaml "$P"/weasel/cangjie5_fluency.dict.yaml "$U"/
printf 'patch:\n  schema_list:\n    - schema: cangjie5_fluency\n' > "$U/default.custom.yaml"
time "$R/usr/bin/rime_deployer" --build "$U" "${SHARED:-$P/testenv/shared}"
echo "build exit=$?"
ls -l "$U/build"
