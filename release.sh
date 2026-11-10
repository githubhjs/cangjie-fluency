#!/usr/bin/env bash
# Build dist/cangjie-fluency-<version>.zip (installer + schema files). Does NOT include the 41 MB language model:
# install.ps1 downloads it from upstream.
# Usage: ./release.sh v0.1.0          build the zip only
#        ./release.sh v0.1.0 --draft  also create a DRAFT GitHub release (not public until you publish it)
set -eu
V="${1:?usage: ./release.sh vX.Y.Z [--draft]}"
cd "$(dirname "$0")"
mkdir -p dist
python3 - "$V" <<'PY'
import sys, zipfile, pathlib
v = sys.argv[1]
out = pathlib.Path("dist") / f"cangjie-fluency-{v}.zip"
files = {
    "install.ps1": "install.ps1",
    "install.bat": "install.bat",
    "LICENSE": "LICENSE",
    "README.md": "README.md",
    "weasel/cangjie5_fluency.schema.yaml": "weasel/cangjie5_fluency.schema.yaml",
    "weasel/cangjie5_fluency.dict.yaml": "weasel/cangjie5_fluency.dict.yaml",
    "weasel/cangjie5_fluency_v2.schema.yaml": "weasel/cangjie5_fluency_v2.schema.yaml",
    "weasel/cangjie3_fluency.schema.yaml": "weasel/cangjie3_fluency.schema.yaml",
    "weasel/cangjie3_fluency.dict.yaml": "weasel/cangjie3_fluency.dict.yaml",
    "tools/cin2rime.py": "tools/cin2rime.py",
    "weasel/README.zh-TW.md": "weasel/README.zh-TW.md",
}
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for src, dst in files.items():
        z.write(src, f"cangjie-fluency-{v}/{dst}")
print(out, out.stat().st_size, "bytes")
PY
if [ "${2:-}" = "--draft" ]; then
  gh release create "$V" "dist/cangjie-fluency-$V.zip" --draft --title "cangjie-fluency $V" \
    --notes "One-click installer for the full-Cangjie sentence input schema (Rime/Weasel). Unzip and double-click install.bat, or run install.ps1. Tested logic on Linux PowerShell; Windows end-to-end test pending. Language model is downloaded from upstream by the script (not in this zip)."
fi
