#!/usr/bin/env bash
# usage: run_eval.sh CASEFILE [extra driver args...]
# Runs the ctypes driver twice (grammar ON / OFF) from the project root layout
#   <project>/rimebin/root   extracted debs
#   <project>/testenv/shared shared data dir (prelude yamls, essay.txt, .gram, cangjie5.base)
#   <project>/testenv/user   user data dir (built)
set -u
P="$(cd "$(dirname "$0")/../.." && pwd)"
R="$P/rimebin/root"
export LD_LIBRARY_PATH="$R/usr/lib/aarch64-linux-gnu"
CASES="$1"; shift
mapfile -t C < "$CASES"
for g in "" "--no-grammar"; do
  python3 -I "$P/weasel/docs/rime_driver.py" --root "$R" --shared "${SHARED:-$P/testenv/shared}" \
    --user "${USERDIR:-$P/testenv/user}" --base "$P/testenv/shared/cangjie5.base.dict.yaml" \
    $g "$@" "${C[@]}" 2>&1
done
