#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -n "$1" ]; then
  OUTDIR="$1"
elif [ -f "$(pwd)/metadata.yml" ] && [ -d "$(pwd)/chapters" ]; then
  OUTDIR="$(pwd)"
else
  OUTDIR="$DIR"
fi
REPORT="$OUTDIR/Laporan.docx"

# Kanonikalisasi OUTDIR agar tetap valid setelah cd ke TMPDIR.
if [ -d "$OUTDIR" ]; then
  OUTDIR="$(cd "$OUTDIR" && pwd)"
  REPORT="$OUTDIR/Laporan.docx"
fi

# Helper path native: lihat build.sh (konversi path MSYS -> Windows).
native_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s' "$1"
  fi
}

# Resolve Python (handle WindowsApps stub redirector on Windows)
PYTHON_BIN="python3"
if ! command -v python3 >/dev/null 2>&1 || ! python3 -V >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1 && python -V >/dev/null 2>&1; then
    PYTHON_BIN="python"
  fi
fi

if [ ! -d "$OUTDIR/chapters" ]; then
  echo "ERROR: Direktori chapters/ tidak ditemukan."
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

FALLBACK_DIRS=(
  "$OUTDIR"
  "$DIR"
  "$HOME/.agents/skills/laporan-generator/resources"
)

copy_asset() {
  local asset="$1"
  local dest="$2"
  for base in "${FALLBACK_DIRS[@]}"; do
    if [ -e "$base/$asset" ]; then
      cp -r "$base/$asset" "$dest/"
      return 0
    fi
  done
  return 1
}

copy_asset "cover.md" "$TMPDIR" || true
copy_asset "logo.jpg" "$TMPDIR" || true
copy_asset "reference.docx" "$TMPDIR" || true
copy_asset "docx.lua" "$TMPDIR" || true
copy_asset "metadata.yml" "$TMPDIR" || true
copy_asset "references.bib" "$TMPDIR" || true
copy_asset "apa.csl" "$TMPDIR" || true
copy_asset "presets" "$TMPDIR" || true
copy_asset "scripts" "$TMPDIR" || true

if [ -d "$OUTDIR/gambar" ]; then
  cp -r "$OUTDIR/gambar" "$TMPDIR/"
elif [ -d "$DIR/gambar" ]; then
  cp -r "$DIR/gambar" "$TMPDIR/"
fi

cp "$OUTDIR/chapters"/*.md "$TMPDIR/" 2>/dev/null || true

cd "$TMPDIR"

# Path RELATIF terhadap TMPDIR (lihat build.sh).
CHAPTER_FILES=$(find . -maxdepth 1 -name "bab*.md" | sort -V)
if [ -z "$CHAPTER_FILES" ]; then
  echo "ERROR: Tidak ada berkas bab*.md di direktori chapters/."
  exit 1
fi
INPUT_FILES=("cover.md")
while IFS= read -r f; do
  [ -n "$f" ] && INPUT_FILES+=("$f")
done < <(find . -maxdepth 1 -name "bab*.md" | sort -V)

PRESET_LINE=$(grep -E '^[[:space:]]*(preset|margin_preset):' "metadata.yml" 2>/dev/null | head -n 1 | cut -d: -f2-)
PRESET_NAME=$(printf %s "$PRESET_LINE" | grep -o -E '[A-Za-z0-9_-]+' | head -n 1)
PRESET_OPTS=()
if [ -n "$PRESET_NAME" ] && [ -f "presets/${PRESET_NAME}.yml" ]; then
  PRESET_OPTS=("--metadata-file=presets/${PRESET_NAME}.yml")
elif [ -f "presets/unej-faperta.yml" ]; then
  PRESET_OPTS=("--metadata-file=presets/unej-faperta.yml")
fi

pandoc \
  "${INPUT_FILES[@]}" \
  "${PRESET_OPTS[@]}" \
  --metadata-file="metadata.yml" \
  --citeproc \
  --bibliography="references.bib" \
  --csl="apa.csl" \
  --metadata=reference-section-title="DAFTAR PUSTAKA" \
  --top-level-division=chapter \
  --reference-doc="reference.docx" \
  --lua-filter="docx.lua" \
  -o "Laporan-tmp.docx" 2>&1

FINALIZE_SCRIPT="scripts/finalize-docx.py"
PAGENUM_SCRIPT="scripts/docx-pagenum.py"
if [ ! -f "$FINALIZE_SCRIPT" ]; then
  for base in "${FALLBACK_DIRS[@]}"; do
    if [ -f "$base/scripts/finalize-docx.py" ]; then
      FINALIZE_SCRIPT="$base/scripts/finalize-docx.py"
      break
    fi
  done
fi
if [ ! -f "$PAGENUM_SCRIPT" ]; then
  for base in "${FALLBACK_DIRS[@]}"; do
    if [ -f "$base/scripts/docx-pagenum.py" ]; then
      PAGENUM_SCRIPT="$base/scripts/docx-pagenum.py"
      break
    fi
  done
fi

export PYTHONUTF8=1
"$PYTHON_BIN" "$(native_path "$FINALIZE_SCRIPT")" "Laporan-tmp.docx" "Laporan-sect.docx"
"$PYTHON_BIN" "$(native_path "$PAGENUM_SCRIPT")" "Laporan-sect.docx" "$(native_path "$REPORT")"

echo "=== DOCX BERHASIL DIBUAT ==="
echo "Lokasi: $REPORT"
