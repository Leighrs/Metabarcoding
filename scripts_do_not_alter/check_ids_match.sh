#!/bin/bash
set -euo pipefail

# ============================================================
# Metabarcoding input validation + optional metadata ID remap
#
# What this script does:
#  1. Resolves current project and input file paths
#  2. Finds samplesheet and metadata
#  3. Verifies both are tab-delimited
#  4. Optionally normalizes IDs for comparison
#  5. Optionally applies an explicit ID mapping file to metadata
#  6. Compares sample IDs between samplesheet and metadata
#  7. Optionally rewrites metadata first-column IDs (with backup)
#  8. Writes metadata path into the Nextflow params JSON
#
# Optional environment variables:
#   METABARCODING_SAMPLESHEET   absolute path to samplesheet
#   METABARCODING_METADATA      absolute path to metadata
#   METABARCODING_ID_MAP        absolute path to 2-column tab-delimited map:
#                                 wrong_metadata_id <tab> correct_samplesheet_id
#   METABARCODING_NORMALIZE_IDS 1=yes, 0=no   (default: 1)
#   METABARCODING_REWRITE_METADATA 1=yes, 0=no (default: 0)
#
# Exit codes:
#   0 success
#   1 configuration / file / formatting error
#   2 ID mismatch detected
# ============================================================

# ------------------ helpers ------------------
die() {
  echo "ERROR: $*" >&2
  exit 1
}

warn() {
  echo "WARNING: $*" >&2
}

info() {
  echo "$*"
}

cleanup() {
  [[ -n "${tmpdir:-}" && -d "${tmpdir:-}" ]] && rm -rf "$tmpdir"
}
trap cleanup EXIT

require_file() {
  local file="$1"
  local label="$2"
  [[ -f "$file" ]] || die "$label not found: $file"
}

check_allowed_extension() {
  local file="$1"
  local label="$2"
  case "$file" in
    *.txt|*.tsv) ;;
    *) die "$label must be .txt or .tsv (tab-delimited). Found: $file" ;;
  esac
}

check_tab_delimited() {
  local file="$1"
  local label="$2"

  require_file "$file" "$label"

  if ! grep -q $'\t' "$file"; then
    die "$label does not appear to be tab-delimited: $file
No tab characters were found.
Please export as a TAB-delimited .txt/.tsv file (not CSV)."
  fi

  local header_cols
  header_cols="$(head -n 1 "$file" | awk -F'\t' '{print NF}')"

  if [[ "$header_cols" -lt 2 ]]; then
    die "$label header appears malformed: $file
Header does not contain multiple tab-separated columns.
Please check the file formatting."
  fi
}

abs_path() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
  else
    echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
  fi
}

# Resolve yes/no-ish env vars safely
env_is_true() {
  local value="${1:-0}"
  case "${value,,}" in
    1|true|yes|y) return 0 ;;
    *) return 1 ;;
  esac
}
# ---------------------------------------------


# ------------------ project ------------------
PROJECT_NAME_FILE="/group/ajfingergrp/Metabarcoding/Project_Runs/Project_IDs/$USER/current_project_name.txt"
require_file "$PROJECT_NAME_FILE" "Current project name file"

PROJECT_NAME="$(cat "$PROJECT_NAME_FILE")"
[[ -n "$PROJECT_NAME" ]] || die "Project name file is empty: $PROJECT_NAME_FILE"

PROJECT_ROOT="/group/ajfingergrp/Metabarcoding/Project_Runs/$PROJECT_NAME"
INPUT_DIR="$PROJECT_ROOT/input"
PARAMS_JSON="$PROJECT_ROOT/params/${PROJECT_NAME}_nf-params.json"

[[ -d "$INPUT_DIR" ]] || die "Input directory not found: $INPUT_DIR"
require_file "$PARAMS_JSON" "Params JSON"
# ---------------------------------------------


# ------------------ settings ------------------
NORMALIZE_IDS="${METABARCODING_NORMALIZE_IDS:-1}"
REWRITE_METADATA="${METABARCODING_REWRITE_METADATA:-0}"
# ----------------------------------------------


# ------------------ samplesheet ------------------
SAMPLESHEET_DEFAULT="$INPUT_DIR/${PROJECT_NAME}_samplesheet.txt"
SAMPLESHEET="${METABARCODING_SAMPLESHEET:-$SAMPLESHEET_DEFAULT}"

require_file "$SAMPLESHEET" "Samplesheet"
check_allowed_extension "$SAMPLESHEET" "Samplesheet"
check_tab_delimited "$SAMPLESHEET" "Samplesheet"
# -------------------------------------------------


# ------------------ metadata resolution ------------------
if [[ -n "${METABARCODING_METADATA:-}" ]]; then
  METADATA="$METABARCODING_METADATA"
else
  mapfile -t candidates < <(
    find "$INPUT_DIR" -maxdepth 1 -type f \
      \( -iname '*.txt' -o -iname '*.tsv' \) \
      ! -samefile "$SAMPLESHEET" \
      -print
  )

  if [[ ${#candidates[@]} -eq 0 ]]; then
    die "No candidate metadata file found in:
  $INPUT_DIR
Expected a .txt or .tsv file (tab-delimited), excluding the samplesheet.
You can also set METABARCODING_METADATA explicitly."
  fi

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

  mapfile -t metadata_named < <(
    printf '%s\n' "${filtered[@]}" | awk 'BEGIN{IGNORECASE=1} /metadata/'
  )

  if [[ ${#metadata_named[@]} -eq 1 ]]; then
    METADATA="${metadata_named[0]}"
  elif [[ ${#metadata_named[@]} -gt 1 ]]; then
    echo "ERROR: Multiple metadata files found (all contain 'metadata'):" >&2
    printf '  %s\n' "${metadata_named[@]}" >&2
    echo >&2
    echo "Set METABARCODING_METADATA explicitly to choose one, e.g.:" >&2
    echo "  export METABARCODING_METADATA=\"${metadata_named[0]}\"" >&2
    exit 1
  else
    echo "ERROR: No metadata file found in $INPUT_DIR with 'metadata' in the filename." >&2
    echo "Candidates seen (.txt/.tsv excluding samplesheet):" >&2
    printf '  %s\n' "${filtered[@]}" >&2
    echo >&2
    echo "Rename your metadata file to include 'metadata' or set METABARCODING_METADATA." >&2
    exit 1
  fi
fi

require_file "$METADATA" "Metadata"
check_allowed_extension "$METADATA" "Metadata"
check_tab_delimited "$METADATA" "Metadata"
# ----------------------------------------------------------


# ------------------ temp files ------------------
tmpdir="$(mktemp -d)"

RAW_SS_IDS="$tmpdir/raw_samplesheet_ids.txt"
RAW_MD_IDS="$tmpdir/raw_metadata_ids.txt"
SS_IDS="$tmpdir/samplesheet_ids.txt"
MD_IDS="$tmpdir/metadata_ids.txt"
MISSING_IN_METADATA="$tmpdir/missing_in_metadata.txt"
MISSING_IN_SAMPLESHEET="$tmpdir/missing_in_samplesheet.txt"

METADATA_FOR_COMPARE="$METADATA"
MAPPED_METADATA_TMP=""
# ------------------------------------------------


# ------------------ optional metadata ID remap ------------------
# Map file format (tab-delimited, with header):
# wrong_metadata_id    correct_samplesheet_id
if [[ -n "${METABARCODING_ID_MAP:-}" ]]; then
  ID_MAP="$METABARCODING_ID_MAP"

  require_file "$ID_MAP" "ID mapping file"
  check_allowed_extension "$ID_MAP" "ID mapping file"
  check_tab_delimited "$ID_MAP" "ID mapping file"

  MAPPED_METADATA_TMP="$tmpdir/metadata.remapped.tsv"

  awk -F'\t' -v OFS='\t' '
    NR==FNR {
      gsub(/\r/, "", $0)
      if (FNR == 1) next
      if ($1 == "" || $2 == "") next

      src = $1
      dst = $2

      if (src in map) {
        print "ERROR: Duplicate source ID in mapping file: " src > "/dev/stderr"
        exit 10
      }
      if (dst in seen_dst) {
        print "ERROR: Duplicate target ID in mapping file: " dst > "/dev/stderr"
        exit 11
      }

      map[src] = dst
      seen_dst[dst] = 1
      next
    }

    {
      gsub(/\r/, "", $0)

      if (FNR == 1) {
        print
        next
      }

      if ($1 in map) {
        $1 = map[$1]
      }

      print
    }
  ' "$ID_MAP" "$METADATA" > "$MAPPED_METADATA_TMP" || die "Failed applying ID mapping file."

  METADATA_FOR_COMPARE="$MAPPED_METADATA_TMP"

  info "Applied ID remapping from:"
  info "  $ID_MAP"
fi
# ---------------------------------------------------------------


# ------------------ extract IDs ------------------
# First column only, skip header, trim CR, ignore empty strings
awk -F'\t' '
  NR>1 {
    gsub(/\r/, "", $1)
    if ($1 != "") print $1
  }
' "$SAMPLESHEET" | sort -u > "$RAW_SS_IDS"

awk -F'\t' '
  NR>1 {
    gsub(/\r/, "", $1)
    if ($1 != "") print $1
  }
' "$METADATA_FOR_COMPARE" | sort -u > "$RAW_MD_IDS"

[[ -s "$RAW_SS_IDS" ]] || die "No sample IDs found in samplesheet (after header).
Check formatting: tab-delimited with sampleID as the first column."

[[ -s "$RAW_MD_IDS" ]] || die "No IDs found in metadata (after header).
Check formatting: tab-delimited with ID as the first column."
# -----------------------------------------------


# ------------------ optional normalization ------------------
# Normalization is ONLY used for comparison, not for file rewriting.
if env_is_true "$NORMALIZE_IDS"; then
  awk '
    {
      x = $0
      gsub(/\r/, "", x)
      gsub(/^[ \t]+|[ \t]+$/, "", x)
      x = tolower(x)
      gsub(/[-_ ]+/, "", x)
      print x
    }
  ' "$RAW_SS_IDS" | sort -u > "$SS_IDS"

  awk '
    {
      x = $0
      gsub(/\r/, "", x)
      gsub(/^[ \t]+|[ \t]+$/, "", x)
      x = tolower(x)
      gsub(/[-_ ]+/, "", x)
      print x
    }
  ' "$RAW_MD_IDS" | sort -u > "$MD_IDS"

  info "ID comparison mode: normalized"
  info "  - lowercased"
  info "  - trimmed whitespace"
  info "  - removed hyphens/underscores/spaces"
else
  cp "$RAW_SS_IDS" "$SS_IDS"
  cp "$RAW_MD_IDS" "$MD_IDS"
  info "ID comparison mode: exact"
fi
# -----------------------------------------------------------


# ------------------ compare IDs ------------------
comm -23 "$SS_IDS" "$MD_IDS" > "$MISSING_IN_METADATA"
comm -13 "$SS_IDS" "$MD_IDS" > "$MISSING_IN_SAMPLESHEET"

if [[ -s "$MISSING_IN_METADATA" || -s "$MISSING_IN_SAMPLESHEET" ]]; then
  echo
  echo "=============================================="
  echo "WARNING: Sample ID mismatch between files!"
  echo "DO NOT PROCEED until this is fixed."
  echo "Re-run this script after correcting the files."
  echo "=============================================="
  echo

  if [[ -s "$MISSING_IN_METADATA" ]]; then
    echo "IDs present in SAMPLESHEET but MISSING from METADATA:"
    sed 's/^/  - /' "$MISSING_IN_METADATA"
    echo
  fi

  if [[ -s "$MISSING_IN_SAMPLESHEET" ]]; then
    echo "IDs present in METADATA but MISSING from SAMPLESHEET:"
    sed 's/^/  - /' "$MISSING_IN_SAMPLESHEET"
    echo
  fi

  echo "Samplesheet:           $SAMPLESHEET"
  echo "Metadata (original):   $METADATA"
  echo "Metadata (compared):   $METADATA_FOR_COMPARE"
  [[ -n "${METABARCODING_ID_MAP:-}" ]] && echo "ID map used:           $METABARCODING_ID_MAP"
  echo

  exit 2
else
  echo
  echo "OK: Sample IDs match exactly under the selected comparison mode between:"
  echo "  - $SAMPLESHEET"
  echo "  - $METADATA_FOR_COMPARE"
  echo
fi
# -----------------------------------------------


# ------------------ optionally rewrite real metadata ------------------
if [[ "$METADATA_FOR_COMPARE" != "$METADATA" ]] && env_is_true "$REWRITE_METADATA"; then
  backup="${METADATA}.bak.$(date +%Y%m%d_%H%M%S)"
  cp "$METADATA" "$backup"
  cp "$METADATA_FOR_COMPARE" "$METADATA"

  info "Rewrote metadata first-column IDs using mapping file."
  info "Backup saved to:"
  info "  $backup"
  info "Updated metadata file:"
  info "  $METADATA"

  # Use the rewritten original metadata path going forward
  METADATA_FOR_COMPARE="$METADATA"
elif [[ -n "${METABARCODING_ID_MAP:-}" ]] && ! env_is_true "$REWRITE_METADATA"; then
  warn "ID map was applied for comparison only."
  warn "Metadata file was NOT rewritten."
  warn "To rewrite metadata, set: export METABARCODING_REWRITE_METADATA=1"
fi
# ---------------------------------------------------------------------


# ------------------ update params JSON ------------------
METADATA_ABS="$(abs_path "$METADATA_FOR_COMPARE")"

if command -v jq >/dev/null 2>&1; then
  tmpjson="$tmpdir/params.json.tmp"
  jq --arg md "$METADATA_ABS" '.metadata = $md' "$PARAMS_JSON" > "$tmpjson" \
    || die "jq failed while updating params JSON: $PARAMS_JSON"
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

info "Set metadata path in params JSON file to:"
info "  $METADATA_ABS"
# -------------------------------------------------------