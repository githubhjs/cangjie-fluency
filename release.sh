#!/usr/bin/env bash
# Build dist/cangjie-fluency-<version>.zip (slim) and dist/cangjie-fluency-<version>-full.zip (everything, works offline).
# The full zip needs the Weasel installer and its licence texts in dl/ (see the deps-v1 release); it is skipped with a warning otherwise.
# Usage: ./release.sh v0.4.0           build both zips
#        ./release.sh v0.4.0 --publish create the GitHub release (NOT a draft) with both zips
set -eu
V="${1:?usage: ./release.sh vX.Y.Z [--publish]}"
cd "$(dirname "$0")"
mkdir -p dist

PAD_REF="${PAD_REF:-v0.4.0}"
PAD_BASE_URL="https://github.com/githubhjs/cangjie-fuzzy-core/releases/download/$PAD_REF"
PAD_ZIP="cangjie-sweep-pad-$PAD_REF.zip"
PAD_SHA="$PAD_ZIP.sha256"

mkdir -p dl
rm -f dl/cangjie-sweep-pad.zip dl/cangjie-sweep-pad.zip.sha256   # never reuse a stale unversioned pad; always rebuild from $PAD_REF
if [ ! -f "dl/cangjie-sweep-pad.zip" ]; then
  if [ -f "dl/$PAD_ZIP" ]; then
    cp "dl/$PAD_ZIP" "dl/cangjie-sweep-pad.zip"
  else
    echo "Downloading $PAD_ZIP..."
    curl -fsSL --retry 3 -o "dl/$PAD_ZIP" "$PAD_BASE_URL/$PAD_ZIP" || true
  fi
fi
if [ ! -f "dl/cangjie-sweep-pad.zip.sha256" ]; then
  if [ -f "dl/$PAD_SHA" ]; then
    cp "dl/$PAD_SHA" "dl/cangjie-sweep-pad.zip.sha256"
  else
    echo "Downloading $PAD_SHA..."
    curl -fsSL --retry 3 -o "dl/$PAD_SHA" "$PAD_BASE_URL/$PAD_SHA" || true
  fi
fi

if [ -f "dl/$PAD_ZIP" ] && [ -f "dl/$PAD_SHA" ]; then
  EXP_PAD_SHA=$(awk '{print $1}' "dl/$PAD_SHA")
  if command -v sha256sum >/dev/null 2>&1; then
    ACT_PAD_SHA=$(sha256sum "dl/$PAD_ZIP" | awk '{print $1}')
  else
    ACT_PAD_SHA=$(shasum -a 256 "dl/$PAD_ZIP" | awk '{print $1}')
  fi
  if [ "$EXP_PAD_SHA" != "$ACT_PAD_SHA" ]; then
    echo "ERROR: Sweep pad SHA-256 mismatch (expected $EXP_PAD_SHA, got $ACT_PAD_SHA)" >&2
    exit 1
  fi
  cp "dl/$PAD_ZIP" "dl/cangjie-sweep-pad.zip"
  cp "dl/$PAD_SHA" "dl/cangjie-sweep-pad.zip.sha256"
fi

python3 - "$V" <<'PY'
import sys, zipfile, pathlib, os
v = sys.argv[1]
root = pathlib.Path(".")
slim = ["install.ps1", "install.bat", "LICENSE", "README.md",
        "weasel/cangjie5_fluency.schema.yaml", "weasel/cangjie5_fluency.dict.yaml", "weasel/cangjie5_fluency_v2.schema.yaml",
        "weasel/cangjie3_fluency.schema.yaml", "weasel/cangjie3_fluency.dict.yaml", "weasel/README.zh-TW.md",
        "weasel/cangjie3_fuzzy.schema.yaml", "weasel/cangjie3_fuzzy_prism.schema.yaml",
        "weasel/cangjie5_fuzzy.schema.yaml", "weasel/cangjie5_fuzzy_prism.schema.yaml",
        "weasel/fuzzy-narrow/cangjie3_fuzzy.schema.yaml",
        "weasel/fuzzy-narrow/cangjie3_fuzzy_prism.schema.yaml",
        "weasel/fuzzy-narrow/cangjie5_fuzzy.schema.yaml",
        "weasel/fuzzy-narrow/cangjie5_fuzzy_prism.schema.yaml",
        "weasel/fuzzy-wide/cangjie3_fuzzy.schema.yaml",
        "weasel/fuzzy-wide/cangjie3_fuzzy_prism.schema.yaml",
        "weasel/fuzzy-wide/cangjie5_fuzzy.schema.yaml",
        "weasel/fuzzy-wide/cangjie5_fuzzy_prism.schema.yaml",
        "tools/cin2rime.py", "tools/cin2rime.pl",
        "tables/mscj3.cin", "tables/mscj3-ext.cin", "tables/cj5.cin", "tables/cangjie5.base.dict.yaml", "tables/SHA256SUMS", "tables/README.md"]
full_extra = ["data/zh-hant-t-essay-bgw.gram", "data/essay.txt", "data/SHA256SUMS", "data/README.md"]
deps = {"dl/weasel-0.17.4.0-installer.exe": "deps/weasel-0.17.4.0-installer.exe",
        "dl/NOTICE-third-party.txt": "deps/NOTICE-third-party.txt",
        "dl/weasel-LICENSE.txt": "deps/weasel-LICENSE.txt",
        "dl/SHA256SUMS-deps": "deps/SHA256SUMS-deps",
        "dl/cangjie-sweep-pad.zip": "sweep-pad/cangjie-sweep-pad.zip",
        "dl/cangjie-sweep-pad.zip.sha256": "sweep-pad/cangjie-sweep-pad.zip.sha256"}


def build(name, items):
    out = pathlib.Path("dist") / name
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for src, dst in items:
            z.write(src, f"cangjie-fluency-{v}/{dst}")
    print(out, out.stat().st_size, "bytes")


build(f"cangjie-fluency-{v}.zip", [(f, f) for f in slim])
missing = [s for s in deps if not os.path.exists(s)]
if missing:
    print("WARNING: full zip skipped, missing:", missing)
else:
    build(f"cangjie-fluency-{v}-full.zip", [(f, f) for f in slim + full_extra] + list(deps.items()))
PY
if [ "${2:-}" = "--publish" ]; then
  ASSETS=("dist/cangjie-fluency-$V.zip")
  [ -f "dist/cangjie-fluency-$V-full.zip" ] && ASSETS+=("dist/cangjie-fluency-$V-full.zip")
  gh release create "$V" "${ASSETS[@]}" --title "cangjie-fluency $V" --notes-file "dist/NOTES-$V.md"
fi
