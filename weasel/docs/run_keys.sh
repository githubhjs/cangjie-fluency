#!/usr/bin/env bash
# usage: run_keys.sh SCHEMA_ID USERDIR_NAME CASEFILE   (model ON, no Return learning)
set -u
P="$(cd "$(dirname "$0")/../.." && pwd)"
R="$P/rimebin/root"
export LD_LIBRARY_PATH="$R/usr/lib/aarch64-linux-gnu"
mapfile -t C < "$3"
python3 -I "$P/weasel/docs/rime_driver.py" --root "$R" --shared "${SHARED:-$P/testenv/shared_nogy}" \
  --user "$P/testenv/$2" --base "${BASE:-$P/testenv/shared/cangjie5.base.dict.yaml}" \
  --schema "$1" --no-commit "${C[@]}" 2>&1
