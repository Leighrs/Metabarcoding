#!/bin/bash
set -euo pipefail

# Read project name
# Read project name
PROJECT_NAME=$(cat "$HOME/Metabarcoding/current_project_name.txt")

# Allow override via environment variables
SAMPLESHEET_DEFAULT="$HOME/Metabarcoding/${PROJECT_NAME}/input/${PROJECT_NAME}_samplesheet.txt"
METADATA_DEFAULT="$HOME/Metabarcoding/${PROJECT_NAME}/input/${PROJECT_NAME}_metadata.txt"

SAMPLESHEET="${METABARCODING_SAMPLESHEET:-$SAMPLESHEET_DEFAULT}"
METADATA="${METABARCODING_METADATA:-$METADATA_DEFAULT}"


if [[ ! -f "$SAMPLESHEET" ]]; then
  echo "ERROR: Samplesheet not found:"
  echo "  $SAMPLESHEET"
  exit 1
fi

if [[ ! -f "$METADATA" ]]; then
  echo "ERROR: Metadata file not found:"
  echo "  $METADATA"
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

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
