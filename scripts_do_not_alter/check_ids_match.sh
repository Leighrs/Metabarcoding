#!/bin/bash
set -euo pipefail

# Read project name
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")

INPUT_DIR="$HOME/Metabarcoding/${PROJECT_NAME}/input"

SAMPLESHEET_DEFAULT="$INPUT_DIR/${PROJECT_NAME}_samplesheet.txt"
SAMPLESHEET="${METABARCODING_SAMPLESHEET:-$SAMPLESHEET_DEFAULT}"

# Make sure samplesheet exists
if [[ ! -f "$SAMPLESHEET" ]]; then
  echo "ERROR: Samplesheet not found:"
  echo "  $SAMPLESHEET"
  exit 1
fi

# ------------------ Resolve metadata file ------------------
# Env override wins; otherwise auto-detect a likely metadata *.txt/*.tsv in input/
if [[ -n "${METABARCODING_METADATA:-}" ]]; then
  METADATA="$METABARCODING_METADATA"
else
  # Candidate files: .txt/.tsv in INPUT_DIR excluding samplesheet
  mapfile -t candidates < <(
    find "$INPUT_DIR" -maxdepth 1 -type f \
      \( -iname '*.txt' -o -iname '*.tsv' \) \
      ! -samefile "$SAMPLESHEET" \
      -print
  )

  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "ERROR: No candidate metadata file found in:"
    echo "  $INPUT_DIR"
    echo "Expected a .txt or .tsv file (tab-delimited), excluding the samplesheet."
    echo "You can also set METABARCODING_METADATA explicitly."
    exit 1
  fi

  # Filter out common non-metadata helper files
  mapfile -t filtered < <(
    printf '%s\n' "${candidates[@]}" | awk 'BEGIN{IGNORECASE=1}
      !/samplesheet/ &&
      !/fastq/ &&
      !/storage/ &&
      !/path/ &&
      !/readme/ &&
      !/common[_-]?names/ &&
      !/names/ {print}'
  )

  if [[ ${#filtered[@]} -eq 0 ]]; then
    filtered=("${candidates[@]}")
  fi

  # ? Only accept files containing "metadata" in the filename
  mapfile -t metadata_named < <(
    printf '%s\n' "${filtered[@]}" | awk 'BEGIN{IGNORECASE=1} /metadata/'
  )

  if [[ ${#metadata_named[@]} -eq 1 ]]; then
    METADATA="${metadata_named[0]}"

  elif [[ ${#metadata_named[@]} -gt 1 ]]; then
    echo "ERROR: Multiple metadata files found (all contain 'metadata'):"
    printf '  %s\n' "${metadata_named[@]}"
    echo
    echo "Set METABARCODING_METADATA explicitly to choose one, e.g.:"
    echo "  export METABARCODING_METADATA=\"${metadata_named[0]}\""
    exit 1

  else
    echo "ERROR: No metadata file found in $INPUT_DIR with 'metadata' in the filename."
    echo "Candidates seen (.txt/.tsv excluding samplesheet):"
    printf '  %s\n' "${filtered[@]}"
    echo
    echo "Rename your metadata file to include 'metadata' or set METABARCODING_METADATA."
    exit 1
  fi
fi

# Make sure metadata exists (covers env-var case too)
if [[ ! -f "$METADATA" ]]; then
  echo "ERROR: Metadata file not found:"
  echo "  $METADATA"
  exit 1
fi

# Enforce allowed metadata extensions
case "$METADATA" in
  *.txt|*.tsv) ;;
  *)
    echo "ERROR: Metadata file must be .txt or .tsv (tab-delimited)."
    echo "Found:"
    echo "  $METADATA"
    exit 1
    ;;
esac
# ----------------------------------------------------------


# ------------------ Tab-delimited sanity check ------------------
check_tab_delimited() {
  local file="$1"
  local label="$2"

  # Must contain at least one tab anywhere
  if ! grep -q $'\t' "$file"; then
    echo "ERROR: $label does not appear to be tab-delimited:"
    echo "  $file"
    echo "No tab characters were found."
    echo "Please export as a TAB-delimited .txt/.tsv file (not CSV)."
    exit 1
  fi

  # Header should have >= 2 tab-separated columns
  local header_cols
  header_cols=$(head -n 1 "$file" | awk -F'\t' '{print NF}')

  if [[ "$header_cols" -lt 2 ]]; then
    echo "ERROR: $label header appears malformed:"
    echo "  $file"
    echo "Header does not contain multiple tab-separated columns."
    echo "Please check the file formatting."
    exit 1
  fi
}
# ----------------------------------------------------------------


# ---- temp dir + ID extraction ----# Validate both files are tab-delimited before parsing
check_tab_delimited "$SAMPLESHEET" "Samplesheet"
check_tab_delimited "$METADATA" "Metadata"

# ---- temp dir + ID extraction ----

tmpdir=""
cleanup() { [[ -n "${tmpdir:-}" ]] && rm -rf "$tmpdir"; }
trap cleanup EXIT
tmpdir="$(mktemp -d)"

ss_ids="$tmpdir/samplesheet_ids.txt"
md_ids="$tmpdir/metadata_ids.txt"

# Extract first column, skip header, drop blanks, sort unique
awk -F'\t' 'NR>1 {gsub(/\r/,""); if ($1!="") print $1}' "$SAMPLESHEET" | sort -u > "$ss_ids"
awk -F'\t' 'NR>1 {gsub(/\r/,""); if ($1!="") print $1}' "$METADATA"   | sort -u > "$md_ids"

# Basic sanity: non-empty ID lists
if [[ ! -s "$ss_ids" ]]; then
  echo "ERROR: No sampleIDs found in samplesheet (after header)."
  echo "Check formatting: tab-delimited with sampleID as the first column."
  exit 1
fi

if [[ ! -s "$md_ids" ]]; then
  echo "ERROR: No IDs found in metadata (after header)."
  echo "Check formatting: tab-delimited with ID as the first column."
  exit 1
fi
# ----------------------------------

# Compare
missing_in_metadata="$tmpdir/missing_in_metadata.txt"
missing_in_samplesheet="$tmpdir/missing_in_samplesheet.txt"

comm -23 "$ss_ids" "$md_ids" > "$missing_in_metadata"      # in samplesheet, not metadata
comm -13 "$ss_ids" "$md_ids" > "$missing_in_samplesheet"   # in metadata, not samplesheet

if [[ -s "$missing_in_metadata" || -s "$missing_in_samplesheet" ]]; then
  echo
  echo "=============================================="
  echo "WARNING: Sample ID mismatch between files!"
  echo "DO NOT PROCEED until this is fixed."
  echo "Re-run this script after correcting the files."
  echo "=============================================="
  echo

  if [[ -s "$missing_in_metadata" ]]; then
    echo "IDs present in SAMPLESHEET but MISSING from METADATA:"
    sed 's/^/  - /' "$missing_in_metadata"
    echo
  fi

  if [[ -s "$missing_in_samplesheet" ]]; then
    echo "IDs present in METADATA but MISSING from SAMPLESHEET:"
    sed 's/^/  - /' "$missing_in_samplesheet"
    echo
  fi

  echo "Samplesheet: $SAMPLESHEET"
  echo "Metadata:    $METADATA"
  echo
  exit 2
else
  echo
  echo "OK: Sample IDs match exactly between:"
  echo "  - $SAMPLESHEET"
  echo "  - $METADATA"
  echo
fi

# ------------------ Autofill metadata path in params JSON ------------------
PARAMS_JSON="$HOME/Metabarcoding/$PROJECT_NAME/params/${PROJECT_NAME}_nf-params.json"

if [[ ! -f "$PARAMS_JSON" ]]; then
  echo "ERROR: Params JSON not found:"
  echo "  $PARAMS_JSON"
  exit 1
fi

# Use an absolute path (and resolve symlinks if possible)
if command -v realpath >/dev/null 2>&1; then
  METADATA_ABS="$(realpath "$METADATA")"
else
  # portable fallback
  METADATA_ABS="$(cd "$(dirname "$METADATA")" && pwd)/$(basename "$METADATA")"
fi

if command -v jq >/dev/null 2>&1; then
  tmpjson="$(mktemp)"
  jq --arg md "$METADATA_ABS" '.metadata = $md' "$PARAMS_JSON" > "$tmpjson"
  mv "$tmpjson" "$PARAMS_JSON"
else
  python3 - <<'PY' "$PARAMS_JSON" "$METADATA_ABS"
import json, sys
path, md = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
data["metadata"] = md
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
fi

echo "Set metadata path in params JSON file to:"
echo "  $METADATA_ABS"
# --------------------------------------------------------------------------
